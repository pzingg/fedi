defmodule FediServer.Activities do
  @behaviour Fedi.ActivityPub.DatabaseApi

  import Ecto.Query

  require Logger

  alias Ecto.Changeset

  alias Fedi.ActivityStreams.Type.OrderedCollectionPage
  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T

  alias FediServer.Activities.User
  alias FediServer.Activities.Activity
  alias FediServer.Activities.Object
  alias FediServer.Activities.Mailbox
  alias FediServer.HTTPClient
  alias FediServer.Repo

  @users_regex ~r/^\/users\/([^\/]+)($|\/.*)/
  @objects_regex ~r/^\/([^\/]+)\/([A-Z0-9]+)$/

  @doc """
  Returns true if the OrderedCollection at 'inbox'
  contains the specified 'id'.

  Called from SideEffectActor post_inbox.
  """
  def inbox_contains(%URI{} = inbox_iri, %URI{} = id) do
    with {:ok, %URI{} = actor_iri} <- actor_for_inbox(inbox_iri) do
      contains? =
        get_mailbox_items(actor_iri, false)
        |> Enum.member?(URI.to_string(id))

      {:ok, contains?}
    end
  end

  @doc """
  Returns the first ordered collection page of the inbox at
  the specified IRI, for prepending new items.
  """
  def get_inbox(%URI{} = inbox_iri) do
    with {:ok, %URI{} = actor_iri} <- actor_for_inbox(inbox_iri) do
      get_mailbox_page(actor_iri, false)
    end
  end

  @doc """
  Saves the first ordered collection page of the inbox at
  the specified IRI, with new items specified in the
  :create member of the the updates map prepended.

  Note that the new items must not be added
  as independent database entries. Separate calls to Create will do that.
  """
  def update_inbox(%URI{} = inbox_iri, updates) when is_map(updates) do
    with {:ok, %URI{} = actor_iri} <- actor_for_inbox(inbox_iri) do
      update_mailbox(actor_iri, updates, false)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns true if the database has an entry for the IRI and it
  exists in the database.

  Used in federated SideEffectActor and Activity callbacks.
  """
  def owns(%URI{} = id) do
    {:ok, local?(id)}
  end

  @doc """
  Fetches the actor's IRI for the given outbox IRI.

  Used in federated SideEffectActor and `like` Activity callbacks.
  """
  def actor_for_outbox(%URI{path: path} = iri) do
    with true <- local?(iri, "/outbox"),
         {:ok, {nickname, :actors}} <- parse_ulid_or_nickname(iri) do
      {:ok, %URI{iri | path: "/users/#{nickname}"}}
    else
      false ->
        {:error, "Not our actor #{URI.to_string(iri)}"}

      {:error, _} ->
        {:error, "Invalid outbox #{URI.to_string(iri)}"}
    end
  end

  @doc """
  Fetches the actor's IRI for the given inbox IRI.

  Used in federated `accept` and `follow` Activity callbacks.
  """
  def actor_for_inbox(%URI{path: path} = iri) do
    with true <- local?(iri, "/inbox"),
         {:ok, {nickname, :actors}} <- parse_ulid_or_nickname(iri) do
      {:ok, %URI{iri | path: "/users/#{nickname}"}}
    else
      false ->
        {:error, "Not our actor #{URI.to_string(iri)}"}

      {:error, _} ->
        {:error, "Invalid inbox #{URI.to_string(iri)}"}
    end
  end

  @doc """
  Fetches the corresponding actor's outbox IRI for the
  actor's inbox IRI.
  """
  def outbox_for_inbox(%URI{path: path} = iri) do
    with true <- local?(iri, "/inbox"),
         {:ok, {nickname, :actors}} <- parse_ulid_or_nickname(iri) do
      {:ok, %URI{iri | path: "/users/#{nickname}/outbox"}}
    else
      false ->
        {:error, "Not our actor #{URI.to_string(iri)}"}

      {:error, _} ->
        {:error, "Invalid inbox #{URI.to_string(iri)}"}
    end
  end

  @doc """
  Fetches the inbox corresponding to the given actor IRI.

  It is acceptable to just return nil. In this case, the library will
  attempt to resolve the inbox of the actor by remote dereferencing instead.
  """
  def inbox_for_actor(%URI{path: path} = iri) do
    with true <- local?(iri),
         {:ok, {nickname, :actors}} <- parse_ulid_or_nickname(iri) do
      {:ok, %URI{iri | path: "/users/#{nickname}/inbox"}}
    else
      false ->
        {:ok, nil}

      {:error, _} ->
        {:ok, nil}
    end
  end

  @doc """
  Returns true if the database has an entry for the specified
  id. It may not be owned by this application instance.

  Used in federated SideEffectActor.
  """
  def exists(%URI{} = ap_id) do
    [:actors, :objects, :activities]
    |> Enum.reduce_while({:ok, false}, fn schema, acc ->
      if repo_ap_id_exists?(schema, ap_id) do
        {:halt, {:ok, true}}
      else
        {:cont, acc}
      end
    end)
  end

  @doc """
  Returns the database entry for the specified id.
  """
  def get(%URI{} = ap_id) do
    [:actors, :objects, :activities]
    |> Enum.reduce_while({:error, "Not found"}, fn schema, acc ->
      case repo_get_by_ap_id(schema, ap_id) do
        %{__struct__: _module, data: data} ->
          {:halt, Fedi.Streams.JSONResolver.resolve_with_as_context(data)}

        nil ->
          {:cont, acc}

        other ->
          Logger.error("Get failed: Unexpected data returned from Repo: #{inspect(other)}")
          {:halt, {:error, "Internal database error"}}
      end
    end)
  end

  @doc """
  Adds a new entry to the database which must be able to be
  keyed by its id.

  Note that Activity values received from federated peers may also be
  created in the database this way if the Federating Protocol is
  enabled. The client may freely decide to store only the id instead of
  the entire value.

  Under certain conditions and network activities, Create may be called
  multiple times for the same ActivityStreams object.
  """
  def create(as_type) do
    with {:get_actor, %URI{} = actor_iri} <-
           {:get_actor, Utils.get_actor_or_attributed_to_iri(as_type)},
         {:ok, params} <-
           parse_basic_params(as_type),
         {:ok, json_data} <-
           Fedi.Streams.Serializer.serialize(as_type),
         {:ok, recipients} <- APUtils.get_recipients(as_type),
         params <-
           Map.merge(params, %{
             ap_id: URI.to_string(params.ap_id),
             actor: URI.to_string(actor_iri),
             recipients: Enum.map(recipients, &URI.to_string(&1)),
             data: json_data
           }) do
      case repo_insert(params.schema, params) do
        {:ok, object} ->
          {:ok, {as_type, json_data}}

        {:error, %Ecto.Changeset{} = changeset} ->
          if unique_constraint_error(changeset) do
            {:ok, {as_type, json_data}}
          else
            Logger.error("Create failed: #{describe_errors(changeset)}")
            {:error, "Internal database error"}
          end
      end
    else
      {:get_actor, _} ->
        {:error, "Missing actor in activity"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def unique_constraint_error(changeset) do
    Enum.find(changeset.errors, fn {field, {_msg, opts}} ->
      opts[:constraint] == :unique
    end)
  end

  @doc """
  Sets an existing entry to the database based on the value's id.

  Note that Activity values received from federated peers may also be
  updated in the database this way if the Federating Protocol is
  enabled. The client may freely decide to store only the id instead of
  the entire value.
  """
  def update(as_type) do
    with {:get_actor, %URI{} = actor_iri} <-
           {:get_actor, Utils.get_actor_or_attributed_to_iri(as_type)},
         {:ok, params} <-
           parse_basic_params(as_type),
         {:ok, json_data} <-
           Fedi.Streams.Serializer.serialize(as_type),
         {:ok, recipients} <- APUtils.get_recipients(as_type),
         params <-
           Map.merge(params, %{
             ap_id: URI.to_string(params.ap_id),
             actor: URI.to_string(actor_iri),
             recipients: Enum.map(recipients, &URI.to_string(&1)),
             data: json_data
           }),
         {:ok, object} <- repo_update(params.schema, params) do
      {:ok, {as_type, json_data}}
    else
      {:get_actor, _} ->
        {:error, "Missing actor in activity"}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Update failed: #{describe_errors(changeset)}")
        {:error, "Internal database error"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes the entry with the given id.

  delete is only called for federated objects. Deletes from the Social
  API should call Update to create a Tombstone.
  """
  def delete(ap_id) do
    with {:ok, {_ulid_or_nickname, schema}} <- parse_ulid_or_nickname(ap_id) do
      repo_delete(schema, ap_id)
    end
  end

  @doc """
  Returns the first ordered collection page of the outbox
  at the specified IRI, for prepending new items.

  Used in social SideEffectActor post_outbox.
  """
  def get_outbox(outbox_iri) do
    with {:ok, %URI{} = actor_iri} <- actor_for_outbox(outbox_iri) do
      get_mailbox_page(actor_iri, true)
    end
  end

  @doc """
  Saves the first ordered collection page of the outbox at
  the specified IRI, with new items specified in the
  :create member of the the updates map prepended.

  Note that the new items must not be added as independent
  database entries. Separate calls to Create will do that.

  Used in social SideEffectActor post_outbox.
  """
  def update_outbox(%URI{} = outbox_iri, updates) when is_map(updates) do
    with {:ok, %URI{} = actor_iri} <- actor_for_outbox(outbox_iri) do
      update_mailbox(actor_iri, updates, false)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a new IRI id for the provided activity or object. The
  implementation does not need to set the 'id' property and simply
  needs to determine the value.

  The library will handle setting the 'id' property on the
  activity or object provided with the value returned.

  Used in social SideEffectActor post_inbox.
  """
  def new_id(value) do
    with {:ok, {_type_name, category}} <- Utils.get_type_name_and_category(value) do
      ulid = Ecto.ULID.generate()

      case category do
        :actors -> {:error, "Cannot make new id for actors"}
        :activities -> {:ok, URI.parse("http://example.com/activities/#{ulid}")}
        _ -> {:ok, URI.parse("http://example.com/objects/#{ulid}")}
      end
    end
  end

  @doc """
  Obtains the Followers Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  def followers(actor_iri) do
    {:ok, OrderedCollectionPage.new()}
  end

  @doc """
  Obtains the Following Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  def following(actor_iri) do
    {:ok, OrderedCollectionPage.new()}
  end

  @doc """
  Obtains the Liked Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  def liked(actor_iri) do
    {:ok, OrderedCollectionPage.new()}
  end

  @doc """
  Returns a `FediServer.HTTPClient` struct, with credentials built
  from the actor's inbox or outbox IRI.
  """
  def new_transport(%URI{path: path} = box_iri, app_agent)
      when is_binary(app_agent) do
    actor_path =
      path
      |> String.replace_trailing("/inbox", "")
      |> String.replace_trailing("/outbox", "")

    actor_id = %URI{box_iri | path: actor_path}
    make_transport(actor_id, app_agent)
  end

  def new_transport(params, _) do
    Logger.error("Invalid params for transport #{inspect(params)}")
    {:error, "Must provide app_agent and either inbox_iri or outbox_iri"}
  end

  def make_transport(actor_id, app_agent) do
    case repo_get_by_ap_id(:actors, actor_id) do
      %User{} = user ->
        FediServer.HTTPClient.credentialed(user, app_agent)

      _ ->
        {:error, "No actor credentials found"}
    end
  end

  def dereference(%FediServer.HTTPClient{} = client, %URI{} = iri) do
    FediServer.HTTPClient.dereference(client, iri)
  end

  def dereference(%URI{} = box_iri, app_agent, %URI{} = iri) when is_binary(app_agent) do
    with {:ok, client} <- new_transport(box_iri, app_agent) do
      FediServer.HTTPClient.dereference(client, iri)
    end
  end

  def deliver(%FediServer.HTTPClient{} = client, json_body, %URI{} = iri)
      when is_binary(json_body) do
    FediServer.HTTPClient.deliver(client, json_body, iri)
  end

  def deliver(%URI{} = box_iri, app_agent, json_body, %URI{} = iri)
      when is_binary(app_agent) and is_binary(json_body) do
    with {:ok, client} <- new_transport(box_iri, app_agent) do
      FediServer.HTTPClient.deliver(client, json_body, iri)
    end
  end

  def batch_deliver(%FediServer.HTTPClient{} = client, json_body, recipients)
      when is_binary(json_body) and is_list(recipients) do
    FediServer.HTTPClient.batch_deliver(client, json_body, recipients)
  end

  def batch_deliver(%URI{} = box_iri, app_agent, json_body, recipients)
      when is_binary(app_agent) and is_binary(json_body) and is_list(recipients) do
    with {:ok, client} <- new_transport(box_iri, app_agent) do
      FediServer.HTTPClient.batch_deliver(client, json_body, recipients)
    end
  end

  ### Implementation

  def update_mailbox(actor_iri, updates, outgoing) do
    # TODO IMPL handle deletes, etc.
    new_activities = Map.get(updates, :create)

    result =
      Enum.reduce_while(new_activities, [], fn activity, acc ->
        with {:ok, params} <- parse_basic_params(activity) do
          params =
            Map.merge(params, %{
              outgoing: outgoing,
              activity_id: URI.to_string(params.ap_id),
              owner: URI.to_string(actor_iri),
              local: params.local
            })

          case repo_insert(:mailboxes, params) do
            {:ok, %Mailbox{id: id} = mailbox} ->
              {:cont, [{params.ap_id, id} | acc]}

            {:error, changeset} ->
              {:halt, {:error, describe_errors(changeset)}}
          end
        end
      end)

    case result do
      {:error, reason} -> {:error, reason}
      _ -> get_mailbox_page(actor_iri, outgoing)
    end
  end

  def get_mailbox_items(%URI{} = actor_iri, outgoing) do
    actor = URI.to_string(actor_iri)

    from(m in Mailbox,
      join: a in Activity,
      on: a.ap_id == m.activity_id,
      select: a.ap_id,
      where: [owner: ^actor, outgoing: ^outgoing],
      order_by: [desc: :id]
    )
    |> Repo.all()
  end

  def get_mailbox_page(%URI{} = actor_iri, outgoing) do
    actor = URI.to_string(actor_iri)

    result =
      from(m in Mailbox,
        join: a in Activity,
        on: a.ap_id == m.activity_id,
        select: a.data,
        where: [owner: ^actor, outgoing: ^outgoing],
        order_by: [desc: :id],
        limit: 30
      )
      |> Repo.all()

    ordered_item_iters =
      Enum.map(result, &mailbox_to_ordered_item(&1))
      |> Enum.filter(fn iter -> !is_nil(iter) end)

    ordered_items = %P.OrderedItems{alias: "", values: ordered_item_iters}
    {:ok, %T.OrderedCollectionPage{alias: "", properties: %{"orderedItems" => ordered_items}}}
  end

  def mailbox_to_ordered_item(activity_json) do
    case Fedi.Streams.JSONResolver.resolve(activity_json) do
      {:ok, object} -> %P.OrderedItemsIterator{alias: "", member: object}
      _ -> nil
    end
  end

  @doc """
  Returns true if the IRI is for this server.
  """
  def local?(%URI{path: path} = iri, suffix) do
    local?(iri) && String.ends_with?(path, suffix)
  end

  def local?(%URI{scheme: scheme, host: host, port: port} = iri) do
    our_url = FediServerWeb.Endpoint.url()

    case URI.parse(our_url) do
      %URI{scheme: ^scheme, host: ^host, port: ^port} ->
        true

      _ ->
        false
    end
  end

  @doc """
  Returns true if a local IRI exists in the users, objects, or activities table.
  """
  def iri_exists?(%URI{path: path} = iri) do
    with true <- local?(iri),
         {:ok, id, schema} <-
           parse_ulid_or_nickname(iri) do
      repo_exists?(schema, id)
    else
      _ ->
        false
    end
  end

  @doc """
  Looks up a local IRI in the users, objects, or activities table.
  """
  def get_by_iri(%URI{path: path} = iri) do
    with true <- local?(iri),
         {:ok, id, schema} <-
           parse_ulid_or_nickname(iri) do
      repo_get(schema, id)
    else
      _ ->
        nil
    end
  end

  def parse_basic_params(as_type) do
    case Utils.get_id_type_name_and_category(as_type) do
      {:ok, {ap_id, type_name, category}} ->
        if local?(ap_id) do
          case parse_ulid_or_nickname(ap_id) do
            {:ok, {ulid_or_nickname, schema}} ->
              if schema == :actors do
                {:ok,
                 %{
                   schema: schema,
                   ap_id: ap_id,
                   ulid: nil,
                   nickname: ulid_or_nickname,
                   local: true,
                   type: type_name
                 }}
              else
                {:ok,
                 %{
                   schema: schema,
                   ap_id: ap_id,
                   ulid: ulid_or_nickname,
                   nickname: nil,
                   local: true,
                   type: type_name
                 }}
              end

            {:error, reason} ->
              {:error, reason}
          end
        else
          schema =
            case category do
              :activities -> :activities
              :actors -> :actors
              _ -> :objects
            end

          {:ok,
           %{
             schema: schema,
             ulid: nil,
             nickname: nil,
             ap_id: ap_id,
             local: false,
             type: type_name
           }}
        end
    end
  end

  @doc """
  Assumes iri is local.
  """
  def parse_ulid_or_nickname(%URI{path: path} = iri) do
    case Regex.run(@users_regex, path) do
      [_match, nickname, _suffix] ->
        {:ok, {nickname, :actors}}

      _ ->
        case Regex.run(@objects_regex, path) do
          [_match, schema, ulid] ->
            {:ok, {ulid, String.to_atom(schema)}}

          _ ->
            {:error, "Missing schema or id in #{URI.to_string(iri)}"}
        end
    end
  end

  def resolve_and_insert_user(%URI{} = id) do
    app_agent = FediServer.Application.app_agent()

    with client <- HTTPClient.anonymous(app_agent),
         {:ok, json_body} <- HTTPClient.fetch_masto_user(client, id),
         {:ok, data} <- Jason.decode(json_body),
         user <- User.new_from_masto_data(data) do
      User.changeset(user) |> Repo.insert(returning: true)
    end
  end

  def get_public_key(%URI{} = ap_id) do
    with {:ok, %User{public_key: public_key}} <- repo_get_by_ap_id(:actors, ap_id) do
      if is_binary(public_key) && public_key != "" do
        {:ok, public_key}
      else
        {:error, "No public key found"}
      end
    end
  end

  def repo_exists?(:objects, ulid) do
    query = from(Object, where: [id: ^ulid])
    Repo.exists?(query)
  end

  def repo_exists?(:activities, ulid) do
    query = from(Activity, where: [id: ^ulid])
    Repo.exists?(query)
  end

  def repo_exists?(:actors, nickname) do
    query = from(User, where: [nickname: ^nickname])
    Repo.exists?(query)
  end

  def repo_exists?(other, _) do
    {:error, "Invalid schema for exists #{other}"}
  end

  def repo_ap_id_exists?(:objects, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = from(Object, where: [ap_id: ^ap_id])
    Repo.exists?(query)
  end

  def repo_ap_id_exists?(:activities, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = from(Activity, where: [ap_id: ^ap_id])
    Repo.exists?(query)
  end

  def repo_ap_id_exists?(:actors, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = from(User, where: [ap_id: ^ap_id])
    Repo.exists?(query)
  end

  def repo_ap_id_exists?(other, _) do
    {:error, "Invalid schema for ap_id_exists #{other}"}
  end

  def repo_get(:objects, ulid) do
    Repo.get(Object, ulid)
  end

  def repo_get(:activities, ulid) do
    Repo.get(Activity, ulid)
  end

  def repo_get(:actors, nickname) do
    Repo.get_by(User, nickname: nickname)
  end

  def repo_get(other, _) do
    {:error, "Invalid schema for get #{other}"}
  end

  def repo_get_by_ap_id(:objects, %URI{} = ap_id) do
    Repo.get_by(Object, ap_id: URI.to_string(ap_id))
  end

  def repo_get_by_ap_id(:activities, %URI{} = ap_id) do
    Repo.get_by(Activity, ap_id: URI.to_string(ap_id))
  end

  def repo_get_by_ap_id(:actors, %URI{} = ap_id) do
    Repo.get_by(User, ap_id: URI.to_string(ap_id))
  end

  def repo_get_by_ap_id(other, _) do
    {:error, "Invalid schema for get by ap_id #{other}"}
  end

  def repo_insert(:objects, params) do
    ulid = params.ulid || Ecto.ULID.generate()
    Object.changeset(%Object{id: ulid}, params) |> Repo.insert(returning: true)
  end

  def repo_insert(:activities, params) do
    ulid = params.ulid || Ecto.ULID.generate()
    Activity.changeset(%Activity{id: ulid}, params) |> Repo.insert(returning: true)
  end

  def repo_insert(:actors, params) do
    ulid = Ecto.ULID.generate()
    User.changeset(%User{id: ulid}, params) |> Repo.insert(returning: true)
  end

  def repo_insert(:mailboxes, params) do
    Mailbox.changeset(%Mailbox{}, params) |> Repo.insert(returning: true)
  end

  def repo_insert(other, _) do
    {:error, "Invalid schema for insert #{other}"}
  end

  def repo_update(:objects, params) do
    with %Object{} = object <- repo_get_by_ap_id(:object, params.ap_id) do
      Object.changeset(object, params) |> Repo.update(returning: true)
    else
      _ ->
        {:error, "Object %{params.ap_id} not found"}
    end
  end

  def repo_update(:activities, params) do
    with %Activity{} = activity <- repo_get_by_ap_id(:activities, params.ap_id) do
      Activity.changeset(activity, params) |> Repo.update(returning: true)
    else
      _ ->
        {:error, "Activity %{params.ap_id} not found"}
    end
  end

  def repo_update(:actors, params) do
    with %User{} = user <- repo_get_by_ap_id(:actors, params.ap_id) do
      User.changeset(user, params) |> Repo.update(returning: true)
    else
      _ ->
        {:error, "User %{params.ap_id} not found"}
    end
  end

  def repo_update(:mailboxes, params) do
    User.changeset(%Mailbox{id: params.ulid}, params) |> Repo.update(returning: true)
  end

  def repo_update(other, _) do
    {:error, "Invalid schema for insert #{other}"}
  end

  def repo_delete(:objects, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = from(Object, where: [ap_id: ^ap_id])
    Repo.delete_all(query)
  end

  def repo_delete(:activities, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = from(Activity, where: [ap_id: ^ap_id])
    Repo.delete_all(query)
  end

  def repo_delete(:actors, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = from(User, where: [ap_id: ^ap_id])
    Repo.delete_all(query)
  end

  def repo_delete(other, _) do
    {:error, "Invalid schema for delete #{other}"}
  end

  def describe_errors(%Changeset{action: action, data: %{__struct__: module}, errors: errors}) do
    error_str =
      Enum.map(errors, fn {field, _error_keywords} = error ->
        "#{inspect(error)}"
        # to_string(field)
      end)
      |> Enum.join(", ")

    "#{Utils.alias_module(module)} #{action} error on fields: #{error_str}"
  end
end
