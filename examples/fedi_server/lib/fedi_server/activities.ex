defmodule FediServer.Activities do
  @behaviour Fedi.ActivityPub.DatabaseApi

  import Ecto.Query

  require Logger

  alias Ecto.Changeset

  alias Fedi.Streams.Error
  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T

  alias FediServer.Accounts.User
  alias FediServer.Activities.Activity
  alias FediServer.Activities.Object
  alias FediServer.Activities.Mailbox
  alias FediServer.Activities.FollowingRelationship
  alias FediServer.Activities.ObjectAction
  alias FediServer.Activities.UserCollection
  alias FediServer.HTTPClient
  alias FediServer.Repo

  @objects_regex ~r/^\/users\/([^\/]+)\/(objects|activities)\/([A-Z0-9]+)$/
  @users_or_collections_regex ~r/^\/users\/([^\/]+)($|\/(.+))/

  @doc """
  Returns true if the OrderedCollection at ("/inbox", "/outbox", "/liked", etc.)
  contains the specified 'id'.

  Called from SideEffectActor post_inbox.
  """
  @impl true
  def collection_contains?(%URI{path: path} = coll_id, %URI{} = id) do
    with {:ok, %URI{} = actor_iri} <- actor_for_collection(coll_id) do
      actor_id = URI.to_string(actor_iri)

      query =
        case collection_type(path) do
          {:mailbox, outgoing} ->
            activity_id = URI.to_string(id)

            Mailbox
            |> join(:inner, [m], a in Activity, on: a.ap_id == m.activity_id)
            |> where([m], m.actor == ^actor_id)
            |> where([m], m.outgoing == ^outgoing)
            |> where([m, a], a.ap_id == ^activity_id)

          :liked ->
            activity_id = URI.to_string(id)

            Activity
            |> where([a], a.actor == ^actor_id)
            |> where([a], a.type == "Like")
            |> where([a], a.ap_id == ^activity_id)

          :following ->
            following_id = URI.to_string(id)

            FollowingRelationship
            |> join(:inner, [r], u in User, on: r.following_id == u.id)
            |> join(:inner, [r], g in User, on: r.follower_id == g.id)
            |> where([r, u, g], g.ap_id == ^actor_id)
            |> where([r, u], u.ap_id == ^following_id)
            |> where([r], r.state == ^:accepted)

          :followers ->
            follower_id = URI.to_string(id)

            FollowingRelationship
            |> join(:inner, [r], u in User, on: r.follower_id == u.id)
            |> join(:inner, [r], g in User, on: r.following_id == g.id)
            |> where([r, u, g], g.ap_id == ^actor_id)
            |> where([r, u], u.ap_id == ^follower_id)
            |> where([r], r.state == ^:accepted)

          # Special collections
          _ ->
            nil
        end

      if is_nil(query) do
        {:error, "Can't understand collection #{coll_id}"}
      else
        {:ok, Repo.exists?(query)}
      end
    end
  end

  @doc """
  Returns the ordered collection page ("/inbox", "/outbox", "/liked", etc.)
  at the specified IRI.

  `opts` can include the following keywords:

  - `:page` - if true (the default), return an OrderedCollectionPage,
    otherwise return an OrderedCollection with 'totalItems' and 'first'
    properties.
  - `:page_size` - if `:page` is set, the maximum number of 'orderedItems'
    to include in the result.
  - `:max_id` - if `:page` is set, only include items older than
    than `:max_id`
  - `:min_id` - if `:page` is set, only include items equal to or
    more recent than `:min_id`
  """
  @impl true
  def get_collection(%URI{path: path} = coll_id, opts \\ [page: true]) do
    with {:ok, %URI{} = actor_iri} <- actor_for_collection(coll_id) do
      if Keyword.get(opts, :page, false) do
        ordered_collection_page(actor_iri, path, opts)
      else
        ordered_collection_summary(actor_iri, path, opts)
      end
    end
  end

  def ordered_collection_summary(actor_iri, path, opts) do
    actor_id = URI.to_string(actor_iri)

    query =
      case collection_type(path) do
        {:mailbox, outgoing} ->
          Mailbox
          |> join(:inner, [m], a in Activity, on: a.ap_id == m.activity_id)
          |> where([m], m.actor == ^actor_id)
          |> where([m], m.outgoing == ^outgoing)
          |> select([m, a], count(a.id))

        :liked ->
          ObjectAction
          |> join(:inner, [a], o in Object, on: o.ap_id == a.object)
          |> where([a], a.actor == ^actor_id)
          |> where([a], a.type == :like)
          |> select([a, o], count(o.id))

        :following ->
          FollowingRelationship
          |> where([r], r.follower_id == ^actor_id)
          |> where([r], r.state == ^:accepted)
          |> select([r], count(r.id))

        :followers ->
          FollowingRelationship
          |> where([r], r.following_id == ^actor_id)
          |> where([r], r.state == ^:accepted)
          |> select([r], count(r.id))

        # Special collections
        {:user_collection, name} ->
          coll_id = actor_id <> "/#{name}"

          UserCollection
          |> where([c], c.collection_id == ^coll_id)
          |> select([c], count(c.id))

        _ ->
          nil
      end

    build_summary(query, actor_iri, path, opts)
  end

  def build_summary(nil, _, path, _) do
    {:error, "Can't understand collection #{path}"}
  end

  def build_summary(query, actor_iri, path, opts) do
    type_prop = Fedi.JSONLD.Property.Type.new_type("OrderedCollection")

    coll_id = %URI{actor_iri | path: path}
    id_prop = Fedi.JSONLD.Property.Id.new_id(coll_id)

    first_id = %URI{actor_iri | path: path, query: "page=true"}
    first_prop = %P.First{alias: "", iri: first_id}

    total_items = Repo.one(query) || 0

    total_items_prop = %P.TotalItems{
      alias: "",
      xsd_non_neg_integer_member: total_items,
      has_non_neg_integer_member?: true
    }

    properties = %{
      "type" => type_prop,
      "id" => id_prop,
      "first" => first_prop,
      "totalItems" => total_items_prop
    }

    {:ok, %T.OrderedCollectionPage{alias: "", properties: properties}}
  end

  def ordered_collection_page(actor_iri, path, opts) do
    actor_id = URI.to_string(actor_iri)

    min_id = Keyword.get(opts, :min_id)
    max_id = Keyword.get(opts, :max_id)
    page_size = Keyword.get(opts, :page_size, 30)

    query =
      case collection_type(path) do
        {:mailbox, outgoing} ->
          q =
            Mailbox
            |> join(:inner, [m], a in Activity, on: a.ap_id == m.activity_id)
            |> where([m], m.actor == ^actor_id)
            |> where([m], m.outgoing == ^outgoing)
            |> select([m, a], %{id: a.id, data: a.data})
            |> order_by([a], desc: a.id)
            |> limit(^page_size)

          q =
            if is_nil(min_id) do
              q
            else
              q |> where([m, a], a.ap_id >= ^min_id)
            end

          if is_nil(max_id) do
            q
          else
            q |> where([m, a], a.ap_id <= ^max_id)
          end

        :liked ->
          q =
            ObjectAction
            |> join(:inner, [a], o in Object, on: o.ap_id == a.object)
            |> where([a], a.actor == ^actor_id)
            |> where([a], a.type == :like)
            |> select([a, o], %{id: o.id, data: o.data})
            |> order_by([a, o], desc: o.id)
            |> limit(^page_size)

          q =
            if is_nil(min_id) do
              q
            else
              q |> where([a, o], o.id >= ^min_id)
            end

          if is_nil(max_id) do
            q
          else
            q |> where([a, o], o.id <= ^max_id)
          end

        :following ->
          q =
            FollowingRelationship
            |> where([r], r.follower_id == ^actor_id)
            |> where([r], r.state == ^:accepted)
            |> select([r], %{id: r.id, iri: r.following_id})
            |> order_by([r], desc: r.id)
            |> limit(^page_size)

          q =
            if is_nil(min_id) do
              q
            else
              q |> where([r], r.id >= ^min_id)
            end

          if is_nil(max_id) do
            q
          else
            q |> where([r], r.id <= ^max_id)
          end

        :followers ->
          q =
            FollowingRelationship
            |> where([r], r.following_id == ^actor_id)
            |> where([r], r.state == ^:accepted)
            |> select([r], %{id: r.id, iri: r.follower_id})
            |> order_by([r], desc: r.id)
            |> limit(^page_size)

          q =
            if is_nil(min_id) do
              q
            else
              q |> where([r], r.id >= ^min_id)
            end

          if is_nil(max_id) do
            q
          else
            q |> where([r], r.id <= ^max_id)
          end

        # Special collections
        {:user_collection, name} ->
          coll_id = actor_id <> "/#{name}"

          q =
            UserCollection
            |> where([c], c.collection_id == ^coll_id)
            |> select([c], %{id: c.id, iri: c.object})
            |> order_by([c], desc: c.id)
            |> limit(^page_size)

          q =
            if is_nil(min_id) do
              q
            else
              q |> where([c], c.id >= ^min_id)
            end

          if is_nil(max_id) do
            q
          else
            q |> where([c], c.id <= ^max_id)
          end

        _ ->
          nil
      end

    build_page(query, actor_iri, path, opts)
  end

  def collection_type(%URI{path: path}), do: collection_type(path)

  def collection_type(path) when is_binary(path) do
    case Path.basename(path) do
      "inbox" -> {:mailbox, false}
      "outbox" -> {:mailbox, true}
      "liked" -> :liked
      "following" -> :following
      "followers" -> :followers
      other -> {:user_collection, other}
    end
  end

  def build_page(nil, _, path, _) do
    {:error, "Can't understand collection #{path}"}
  end

  def build_page(query, actor_iri, path, opts) do
    result = Repo.all(query)

    ordered_item_iters =
      Enum.map(result, fn
        %{iri: iri} when is_binary(iri) ->
          %P.OrderedItemsIterator{alias: "", iri: Utils.to_uri(iri)}

        %{data: data} when is_map(data) ->
          case resolve_with_stripped_recipients(data) do
            {:ok, object} ->
              %P.OrderedItemsIterator{alias: "", member: object}

            _ ->
              Logger.error("For #{path} could not resolve #{inspect(data)}")
              nil
          end

        item ->
          Logger.error("For #{path} don't know how to map #{inspect(item)}")
          nil
      end)
      |> Enum.filter(fn iter -> !is_nil(iter) end)

    ordered_items_prop = %P.OrderedItems{alias: "", values: ordered_item_iters}

    type_prop = Fedi.JSONLD.Property.Type.new_type("OrderedCollectionPage")

    page_id = %URI{actor_iri | path: path, query: "page=true"}
    id_prop = Fedi.JSONLD.Property.Id.new_id(page_id)

    coll_id = %URI{actor_iri | path: path}
    part_of_prop = %P.PartOf{alias: "", iri: coll_id}

    properties = %{
      "type" => type_prop,
      "id" => id_prop,
      "partOf" => part_of_prop,
      "orderedItems" => ordered_items_prop
    }

    # TODO handle Keyword.get(opts, :min_id)
    properties =
      case List.last(result) do
        %{id: last_id} ->
          next_id = %URI{actor_iri | path: path, query: "max_id=#{last_id}&page=true"}
          next_prop = %P.Next{alias: "", iri: next_id}
          Map.put(properties, "next", next_prop)

        _ ->
          properties
      end

    {:ok, %T.OrderedCollectionPage{alias: "", properties: properties}}
  end

  @doc """
  Updates the ordered collection page ("/inbox", "/outbox", "/liked", etc.)
  the specified IRI, with new items specified in the
  :add member of the the `updates` map prepended.

  Note that the new items must not be added
  as independent database entries. Separate calls to Create will do that.
  """
  @impl true
  def update_collection(%URI{path: path} = coll_id, updates) when is_map(updates) do
    with {:ok, %URI{} = actor_iri} <- actor_for_collection(coll_id),
         {:valid_type, type} when not is_nil(type) <- {:valid_type, collection_type(path)} do
      # TODO Handle deletes, etc.
      new_items = Map.get(updates, :add, [])
      items_to_be_removed = Map.get(updates, :remove, [])

      Enum.reduce_while(new_items, [], fn item, acc ->
        add_collection_item(type, actor_iri, item, acc)
      end)
      |> case do
        {:error, reason} ->
          {:error, reason}

        _ ->
          case remove_collection_items(type, actor_iri, items_to_be_removed) do
            {:error, reason} ->
              {:error, reason}

            _ ->
              get_collection(coll_id)
          end
      end
    else
      {:error, reason} -> {:error, reason}
      {:valid_type, _} -> {:error, "Can't understand collection #{coll_id}"}
    end
  end

  def add_collection_item({:mailbox, outgoing}, %URI{} = actor_iri, activity, acc) do
    with {:ok, params} <- parse_basic_params(activity),
         {:ok, object_id} <- APUtils.get_object_id(activity) do
      visibility = APUtils.get_visibility(activity, actor_iri)

      params =
        Map.merge(params, %{
          outgoing: outgoing,
          activity_id: URI.to_string(params.ap_id),
          actor: URI.to_string(actor_iri),
          object: URI.to_string(object_id),
          visibility: visibility,
          local: params.local
        })

      case repo_insert(:mailboxes, params) do
        {:ok, %Mailbox{id: id} = mailbox} ->
          {:cont, [{params.ap_id, id} | acc]}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    else
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  def add_collection_item(:liked, %URI{} = actor_iri, object_id, acc) do
    Logger.error("#{actor_iri} liked #{object_id}")

    params = %{
      actor: URI.to_string(actor_iri),
      object: URI.to_string(object_id)
    }

    case repo_insert(:likes, params) do
      {:ok, %ObjectAction{}} ->
        {:cont, [object_id | acc]}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  def add_collection_item(:following, %URI{} = actor_iri, %URI{} = following_id, acc) do
    Logger.error("#{actor_iri} following #{following_id}")

    case follow(actor_iri, following_id) do
      {:ok, %FollowingRelationship{}} -> {:cont, [following_id | acc]}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  def add_collection_item(:followers, %URI{} = actor_iri, %URI{} = follower_id, acc) do
    Logger.error("#{actor_iri} followers #{follower_id}")

    case follow(follower_id, actor_iri) do
      {:ok, %FollowingRelationship{}} -> {:cont, [follower_id | acc]}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  def add_collection_item({:user_collection, name}, %URI{} = actor_id, %URI{} = object_id, acc) do
    # TODO dereference to get object_type?
    object_type = "Unknown"
    actor = URI.to_string(actor_id)
    coll_id = actor <> "/#{name}"
    Logger.error("collection #{coll_id} object #{object_id}")

    params = %{
      collection_id: coll_id,
      type: object_type,
      actor: actor,
      object: URI.to_string(object_id)
    }

    case repo_insert(:collections, params) do
      {:ok, %UserCollection{}} -> {:cont, [object_id | acc]}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  def add_collection_item(type, _actor_id, _object_id, _acc) do
    {:halt, {:error, "Add item unimplemented for #{inspect(type)}"}}
  end

  def remove_collection_items(_type, _actor_id, []), do: :ok

  def remove_collection_items({:user_collection, name}, %URI{} = actor_id, object_ids) do
    # TODO dereference to get object_type?
    actor = URI.to_string(actor_id)
    coll_id = actor <> "/#{name}"
    object_ids = Enum.map(object_ids, &URI.to_string(&1))
    to_delete = Enum.count(object_ids)

    {count_deleted, _} =
      UserCollection
      |> where([c], c.collection_id == ^coll_id)
      |> where([c], c.object in ^object_ids)
      |> Repo.delete_all()

    cond do
      count_deleted == 0 ->
        Logger.error("None of #{to_delete} items were removed from #{coll_id}")
        {:error, "Not found"}

      count_deleted < to_delete ->
        Logger.error("Only #{count_deleted} of #{to_delete} items were removed from #{coll_id}")
        :ok

      true ->
        :ok
    end
  end

  def remove_collection_items(type, _actor_id, _object_ids) do
    {:error, "Remove item unimplemented for #{inspect(type)}"}
  end

  @doc """
  Returns true if the database has an entry for the IRI and it
  exists in the database.

  Used in federated SideEffectActor and Activity callbacks.
  """
  @impl true
  def owns?(%URI{} = id) do
    if local?(id) do
      exists?(id)
    else
      {:ok, false}
    end
  end

  @doc """
  Fetches the actor's IRI for the given collection IRI.

  Used in federated SideEffectActor and `like` Activity callbacks.
  """
  @impl true
  def actor_for_collection(%URI{path: path} = iri) do
    with true <- local?(iri),
         {:ok, :actors, nickname, _} <- parse_iri_schema(iri) do
      {:ok, Utils.base_uri(iri, "/users/#{nickname}")}
    else
      false ->
        {:error, "Not our actor #{iri}"}

      {:error, _} ->
        {:error, "Invalid collection #{iri}"}
    end
  end

  @doc """
  Fetches the actor's IRI for the given outbox IRI.

  Used in federated SideEffectActor and `like` Activity callbacks.
  """
  @impl true
  def actor_for_outbox(%URI{path: path} = iri) do
    with true <- local?(iri, "/outbox"),
         {:ok, :actors, nickname, _} <- parse_iri_schema(iri) do
      {:ok, Utils.base_uri(iri, "/users/#{nickname}")}
    else
      false ->
        {:error, "Not our actor #{iri}"}

      {:error, _} ->
        {:error, "Invalid outbox #{iri}"}
    end
  end

  @doc """
  Fetches the actor's IRI for the given inbox IRI.

  Used in federated `accept` and `follow` Activity callbacks.
  """
  @impl true
  def actor_for_inbox(%URI{path: path} = iri) do
    with true <- local?(iri, "/inbox"),
         {:ok, :actors, nickname, _} <- parse_iri_schema(iri) do
      {:ok, Utils.base_uri(iri, "/users/#{nickname}")}
    else
      false ->
        {:error, "Not our actor #{iri}"}

      {:error, _} ->
        {:error, "Invalid inbox #{iri}"}
    end
  end

  @doc """
  Fetches the corresponding actor's outbox IRI for the
  actor's inbox IRI.
  """
  @impl true
  def outbox_for_inbox(%URI{path: path} = iri) do
    with true <- local?(iri, "/inbox"),
         {:ok, :actors, nickname, _} <- parse_iri_schema(iri) do
      {:ok, Utils.base_uri(iri, "/users/#{nickname}/outbox")}
    else
      false ->
        {:error, "Not our actor #{iri}"}

      {:error, _} ->
        {:error, "Invalid inbox #{iri}"}
    end
  end

  @doc """
  Fetches the inbox corresponding to the given actor IRI.

  It is acceptable to just return nil. In this case, the library will
  attempt to resolve the inbox of the actor by remote dereferencing instead.
  """
  @impl true
  def inbox_for_actor(%URI{path: path} = iri) do
    with true <- local?(iri),
         {:ok, :actors, nickname, _} <- parse_iri_schema(iri) do
      {:ok, Utils.base_uri(iri, "/users/#{nickname}/inbox")}
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
  @impl true
  def exists?(%URI{} = ap_id) do
    [:actors, :objects, :activities, :collections]
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
  @impl true
  def get(%URI{} = ap_id) do
    case get_object_data(ap_id) do
      {:ok, data} ->
        resolve_with_stripped_recipients(data)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_object_data(%URI{} = ap_id) do
    with {:ok, schema, _ulid_or_nickame, _collection} <- parse_iri_schema(ap_id) do
      case repo_get_by_ap_id(schema, ap_id) do
        %{__struct__: _module, data: data} when is_map(data) ->
          {:ok, data}

        nil ->
          {:error, "Not found"}

        other ->
          Logger.error("Get failed: Unexpected data returned from Repo: #{inspect(other)}")
          {:error, "Internal database error"}
      end
    end
  end

  def resolve_with_stripped_recipients(data) when is_map(data) do
    data
    |> APUtils.strip_hidden_recipients()
    |> Fedi.Streams.JSONResolver.resolve_with_as_context()
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
  @impl true
  def create(as_type) do
    with {:get_actor, %URI{} = actor_iri} <-
           {:get_actor, Utils.get_actor_or_attributed_to_iri(as_type)},
         {:ok, params} <-
           parse_basic_params(as_type),
         {:ok, json_data} <-
           Fedi.Streams.Serializer.serialize(as_type),
         {:ok, recipients} <- APUtils.get_recipients(as_type, empty_ok: true),
         params <-
           Map.merge(params, %{
             ap_id: URI.to_string(params.ap_id),
             actor: URI.to_string(actor_iri),
             recipients: Enum.map(recipients, &URI.to_string(&1)),
             data: json_data
           }) do
      case repo_insert(params.schema, params) do
        {:error, reason} ->
          {:error, reason}

        {:ok, _object} ->
          {:ok, as_type, json_data}
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
  @impl true
  def update(as_type) do
    case parse_basic_params(as_type) do
      {:error, reason} ->
        {:error, reason}

      {:ok, %{schema: :activities} = params} ->
        update_activity(as_type, params)

      {:ok, %{schema: :objects} = params} ->
        update_object(as_type, params)

      {:ok, params} ->
        Logger.error("Don't know how to update #{inspect(as_type)}, params #{inspect(params)}")
    end
  end

  def update_activity(as_type, %{schema: :activities} = params) do
    with {:get_actor, %URI{} = actor_iri} <-
           {:get_actor, Utils.get_actor_or_attributed_to_iri(as_type)},
         {:ok, json_data} <-
           Fedi.Streams.Serializer.serialize(as_type),
         {:ok, recipients} <- APUtils.get_recipients(as_type),
         params <-
           Map.merge(params, %{
             actor: URI.to_string(actor_iri),
             recipients: Enum.map(recipients, &URI.to_string(&1)),
             data: json_data
           }),
         {:ok, object} <- repo_update(:activities, params) do
      {:ok, object}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Update failed: #{describe_errors(changeset)}")
        {:error, "Internal database error"}

      {:error, reason} ->
        {:error, reason}

      {:get_actor, _} ->
        {:error, "Missing actor in activity"}
    end
  end

  def update_object(as_type, %{schema: :objects} = params) do
    with {:get_actor, %URI{} = actor_iri} <-
           {:get_actor, Utils.get_iri(as_type, "attributedTo")},
         {:ok, json_data} <-
           Fedi.Streams.Serializer.serialize(as_type),
         params <-
           Map.merge(params, %{
             actor: URI.to_string(actor_iri),
             data: json_data
           }),
         {:ok, object} <- repo_update(:objects, params) do
      {:ok, object}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Update failed: #{describe_errors(changeset)}")
        {:error, "Internal database error"}

      {:error, reason} ->
        {:error, reason}

      {:get_actor, _} ->
        {:error, "Missing attributedTo in object"}
    end
  end

  @doc """
  Removes the entry with the given id.

  delete is only called for federated objects. Deletes from the Social
  API should call Update to create a Tombstone.
  """
  @impl true
  def delete(ap_id) do
    with {:ok, schema, _ulid_or_nickame, _collection} <- parse_iri_schema(ap_id) do
      repo_delete(schema, ap_id)
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
  @impl true
  def new_id(value) do
    # endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()

    with {:get_actor, %URI{path: actor_path} = actor_iri} <-
           {:get_actor, Utils.get_actor_or_attributed_to_iri(value)},
         {:local_actor, true} <- {:local_actor, local?(actor_iri)},
         {:ok, _type_name, category} <- Utils.get_type_name_and_category(value) do
      ulid = Ecto.ULID.generate()

      case category do
        :actors -> {:error, "Cannot make new id for actors"}
        :activities -> {:ok, %URI{actor_iri | path: actor_path <> "/activities/#{ulid}"}}
        _ -> {:ok, %URI{actor_iri | path: actor_path <> "/objects/#{ulid}"}}
      end
    else
      {:error, reason} ->
        {:error, reason}

      {:get_actor, _} ->
        Logger.error(
          "Couldn't get attributed_to in object #{Utils.alias_module(value.__struct__)}"
        )

        {:error, Utils.err_actor_required(object: value)}

      {:local_actor, _} ->
        Logger.error("Actor in object #{Utils.alias_module(value.__struct__)} is not ours")
        {:error, "Internal server error"}
    end
  end

  @doc """
  Returns a `FediServer.HTTPClient` struct, with credentials built
  from the actor's inbox or outbox IRI.
  """
  @impl true
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

  @impl true
  def dereference(%FediServer.HTTPClient{} = client, %URI{} = iri) do
    if local?(iri) do
      get_object_data(iri)
    else
      FediServer.HTTPClient.dereference(client, iri)
    end
  end

  @impl true
  def dereference(%URI{} = box_iri, app_agent, %URI{} = iri) when is_binary(app_agent) do
    if local?(iri) do
      get_object_data(iri)
    else
      with {:ok, client} <- new_transport(box_iri, app_agent) do
        FediServer.HTTPClient.dereference(client, iri)
      end
    end
  end

  @impl true
  def deliver(%FediServer.HTTPClient{} = client, json_body, %URI{} = iri)
      when is_binary(json_body) do
    FediServer.HTTPClient.deliver(client, json_body, iri)
  end

  @impl true
  def deliver(%URI{} = box_iri, app_agent, json_body, %URI{} = iri)
      when is_binary(app_agent) and is_binary(json_body) do
    with {:ok, client} <- new_transport(box_iri, app_agent) do
      FediServer.HTTPClient.deliver(client, json_body, iri)
    end
  end

  @impl true
  def batch_deliver(%FediServer.HTTPClient{} = client, json_body, recipients)
      when is_binary(json_body) and is_list(recipients) do
    FediServer.HTTPClient.batch_deliver(client, json_body, recipients)
  end

  @impl true
  def batch_deliver(%URI{} = box_iri, app_agent, json_body, recipients)
      when is_binary(app_agent) and is_binary(json_body) and is_list(recipients) do
    with {:ok, client} <- new_transport(box_iri, app_agent) do
      FediServer.HTTPClient.batch_deliver(client, json_body, recipients)
    end
  end

  ### Implementation

  def get_following_relationship(%URI{} = follower, %URI{} = following) do
    follower_id = URI.to_string(follower)
    following_id = URI.to_string(following)

    query =
      FollowingRelationship
      |> where([r], r.follower_id == ^follower_id and r.following_id == ^following_id)

    Repo.one(query)
  end

  def update_following_relationship(%URI{} = follower, %URI{} = following, :rejected) do
    unfollow(follower, following)
  end

  def update_following_relationship(%URI{} = follower, %URI{} = following, state) do
    case get_following_relationship(follower, following) do
      nil ->
        follow(follower, following, state)

      following_relationship ->
        following_relationship
        |> FollowingRelationship.state_changeset(%{state: state})
        |> Repo.update()
    end
  end

  def follow(%URI{} = follower, %URI{} = following, state \\ :accepted) do
    params = %{
      follower_id: URI.to_string(follower),
      following_id: URI.to_string(following),
      state: state
    }

    %FollowingRelationship{}
    |> FollowingRelationship.changeset(params)
    |> Repo.insert(on_conflict: :nothing, returning: true)
    |> handle_insert_result(:following)
  end

  def unfollow(%URI{} = follower, %URI{} = following) do
    case get_following_relationship(follower, following) do
      %FollowingRelationship{} = following_relationship ->
        Repo.delete(following_relationship)

      _ ->
        {:ok, nil}
    end
  end

  @doc """
  Returns true if the IRI is for this server.
  """
  def local?(%URI{path: path} = iri, suffix) do
    local?(iri) && String.ends_with?(path, suffix)
  end

  def local?(%URI{} = iri) do
    endpoint_url = Fedi.Application.endpoint_url()
    test_url = Utils.base_uri(iri, "/") |> URI.to_string()

    endpoint_url == test_url
  end

  @doc """
  Returns true if a local IRI exists in the users, objects, or activities table.
  """
  def iri_exists?(%URI{path: path} = iri) do
    with true <- local?(iri),
         {:ok, schema, ulid_or_nickname, _collection} <-
           parse_iri_schema(iri) do
      repo_exists?(schema, ulid_or_nickname)
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
         {:ok, schema, ulid_or_nickname, _collection} <-
           parse_iri_schema(iri) do
      repo_get(schema, ulid_or_nickname)
    else
      _ ->
        nil
    end
  end

  def parse_basic_params(as_type) do
    case Utils.get_id_type_name_and_category(as_type) do
      {:ok, ap_id, type_name, :actors} ->
        case parse_iri_schema(ap_id) do
          {:error, reason} ->
            {:error, reason}

          {:ok, :actors, nickname, _} ->
            if local?(ap_id) do
              Logger.debug("Parsed #{Utils.alias_module(as_type.__struct__)} as local actor")

              {:ok,
               %{
                 schema: :actors,
                 ap_id: ap_id,
                 ulid: nil,
                 nickname: nickname,
                 local: true,
                 type: type_name
               }}
            else
              Logger.debug("Parsed #{Utils.alias_module(as_type.__struct__)} as remote actor")

              {:ok,
               %{
                 schema: :actors,
                 ulid: nil,
                 nickname: nil,
                 ap_id: ap_id,
                 local: false,
                 type: type_name
               }}
            end

          {:ok, _, schema} ->
            Logger.debug("Parsed #{Utils.alias_module(as_type.__struct__)} as ERROR #{schema}")
            {:error, "Bad schema #{schema} for #{type_name}"}
        end

      {:ok, ap_id, type_name, category} ->
        schema =
          if category == :activities || category == :collections do
            category
          else
            :objects
          end

        {:ok,
         %{
           schema: schema,
           ap_id: ap_id,
           ulid: nil,
           nickname: nil,
           local: local?(ap_id),
           type: type_name
         }}
    end
  end

  @doc """
  Assumes iri is local.
  """
  def parse_iri_schema(%URI{path: path} = iri) do
    path = String.trim_trailing(path, "/")

    case Regex.run(@objects_regex, path) do
      [_match, _nickname, schema, ulid] ->
        {:ok, String.to_atom(schema), ulid, nil}

      _ ->
        case Regex.run(@users_or_collections_regex, path) do
          [_match, nickname, _] ->
            {:ok, :actors, nickname, nil}

          [_match, nickname, _, collection_suffix] ->
            {:ok, :actors, nickname, collection_suffix}

          _ ->
            Logger.error("Failed to parse #{iri}")
            {:error, "Missing schema in #{iri}"}
        end
    end
  end

  def ensure_user(%URI{} = id, local?, app_agent \\ nil) do
    case repo_get_by_ap_id(:actors, id) do
      %User{} = user ->
        {:ok, user}

      _ ->
        if local? do
          {:error, "Local user #{id} not found"}
        else
          resolve_and_insert_user(id, app_agent)
        end
    end
  end

  def resolve_and_insert_user(%URI{} = id, app_agent \\ nil) do
    app_agent = app_agent || FediServer.Application.app_agent()

    with client <- HTTPClient.anonymous(app_agent),
         {:ok, json_body} <- HTTPClient.fetch_masto_user(client, id),
         {:ok, data} <- Jason.decode(json_body),
         user <- User.new_remote_user(data) do
      User.changeset(user) |> Repo.insert(returning: true)
    end
  end

  def get_public_key(%URI{} = ap_id) do
    case repo_get_by_ap_id(:actors, ap_id) do
      %User{} = user ->
        User.get_public_key(user)

      _ ->
        {:error, "No user for #{ap_id}"}
    end
  end

  def repo_exists?(:actors, nickname) do
    query = User |> where([u], u.nickname == ^nickname)
    Repo.exists?(query)
  end

  def repo_exists?(:activities, ulid) do
    query = Activity |> where([a], a.id == ^ulid)
    Repo.exists?(query)
  end

  def repo_exists?(:objects, ulid) do
    query = Object |> where([o], o.id == ^ulid)
    Repo.exists?(query)
  end

  def repo_exists?(:collections, ulid) do
    query = UserCollection |> where([c], c.id == ^ulid)
    Repo.exists?(query)
  end

  def repo_exists?(other, _) do
    {:error, "Invalid schema for exists #{other}"}
  end

  def repo_ap_id_exists?(:actors, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = User |> where([u], u.ap_id == ^ap_id)
    Repo.exists?(query)
  end

  def repo_ap_id_exists?(:activities, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = Activity |> where([a], a.ap_id == ^ap_id)
    Repo.exists?(query)
  end

  def repo_ap_id_exists?(:objects, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)

    query = Object |> where([o], o.ap_id == ^ap_id)
    Repo.exists?(query)
  end

  # Mock: we allow any old collection
  def repo_ap_id_exists?(:collections, %URI{} = ap_id) do
    local?(ap_id)
  end

  def repo_ap_id_exists?(other, _) do
    {:error, "Invalid schema for ap_id_exists #{other}"}
  end

  def repo_get(:actors, nickname) do
    Repo.get_by(User, nickname: nickname)
  end

  def repo_get(:activities, ulid) do
    Repo.get(Activity, ulid)
  end

  def repo_get(:objects, ulid) do
    Repo.get(Object, ulid)
  end

  def repo_get(:collections, ulid) do
    Repo.get(UserCollection, ulid)
  end

  def repo_get(other, _) do
    {:error, "Invalid schema for get #{other}"}
  end

  def repo_get_by_ap_id(:actors, %URI{} = ap_id) do
    Repo.get_by(User, ap_id: URI.to_string(ap_id))
  end

  def repo_get_by_ap_id(:activities, %URI{} = ap_id) do
    Repo.get_by(Activity, ap_id: URI.to_string(ap_id))
  end

  def repo_get_by_ap_id(:objects, %URI{} = ap_id) do
    Repo.get_by(Object, ap_id: URI.to_string(ap_id))
  end

  def repo_get_by_ap_id(:collections, %URI{} = ap_id) do
    query = UserCollection |> where([u], u.collection_id == ^ap_id)
    Repo.all(query)
  end

  def repo_get_by_ap_id(other, %URI{} = _) do
    {:error, "Invalid schema for get by ap_id #{other}"}
  end

  def repo_insert(:actors, params) do
    ulid = Ecto.ULID.generate()
    Logger.debug("Inserting user: #{params.ap_id}")

    User.changeset(%User{id: ulid}, params)
    |> Repo.insert(returning: true)
    |> handle_insert_result(:objects)
  end

  def repo_insert(:activities, params) do
    ulid = params.ulid || Ecto.ULID.generate()
    Logger.debug("Inserting activity: #{params.ap_id}")

    Activity.changeset(%Activity{id: ulid}, params)
    |> Repo.insert(returning: true)
    |> handle_insert_result(:objects)
  end

  def repo_insert(:objects, params) do
    ulid = params.ulid || Ecto.ULID.generate()
    Logger.debug("Inserting object: #{params.ap_id}")

    Object.changeset(%Object{id: ulid}, params)
    |> Repo.insert(returning: true)
    |> handle_insert_result(:objects)
  end

  def repo_insert(:mailboxes, params) do
    which_box =
      if params.outgoing do
        "outbox"
      else
        "inbox"
      end

    Logger.debug("Inserting #{which_box}: #{params.activity_id}")

    Mailbox.changeset(%Mailbox{}, params)
    |> Repo.insert(returning: true)
    |> handle_insert_result(:objects)
  end

  def repo_insert(:likes, params) do
    Logger.debug("Inserting like: #{params.object}")

    ObjectAction.changeset(%ObjectAction{}, Map.put(params, :type, :like))
    |> Repo.insert(on_conflict: :nothing, returning: true)
    |> handle_insert_result(:objects)
  end

  def repo_insert(:shares, params) do
    Logger.debug("Inserting share: #{params.object}")

    ObjectAction.changeset(%ObjectAction{}, Map.put(params, :type, :share))
    |> Repo.insert(on_conflict: :nothing, returning: true)
    |> handle_insert_result(:objects)
  end

  def repo_insert(:collections, params) do
    Logger.debug("Inserting collection: #{params.object}")

    # TODO get type of item from params
    UserCollection.changeset(%UserCollection{}, params)
    |> Repo.insert(on_conflict: :nothing, returning: true)
    |> handle_insert_result(params.type)
  end

  def repo_insert(other, _) do
    {:error, "Invalid schema for insert #{other}"}
  end

  def handle_insert_result({:ok, data}, _), do: {:ok, data}

  def handle_insert_result({:error, %Ecto.Changeset{} = changeset}, type) do
    if unique_constraint_error(changeset) do
      {:ok, :already_inserted}
    else
      Logger.error("Failed to insert #{type}: #{describe_errors(changeset)}")
      {:error, "Internal database error"}
    end
  end

  def repo_update(:actors, params) do
    with %User{} = user <- repo_get_by_ap_id(:actors, params.ap_id) do
      params = Map.put(params, :ap_id, URI.to_string(params.ap_id))
      User.changeset(user, params) |> Repo.update(returning: true)
    else
      _ ->
        {:error, "User %{params.ap_id} not found"}
    end
  end

  def repo_update(:activities, params) do
    with %Activity{} = activity <- repo_get_by_ap_id(:activities, params.ap_id) do
      params = Map.put(params, :ap_id, URI.to_string(params.ap_id))
      Activity.changeset(activity, params) |> Repo.update(returning: true)
    else
      _ ->
        {:error, "Activity %{params.ap_id} not found"}
    end
  end

  def repo_update(:objects, params) do
    with %Object{} = object <- repo_get_by_ap_id(:objects, params.ap_id) do
      params = Map.put(params, :ap_id, URI.to_string(params.ap_id))

      try do
        Object.changeset(object, params) |> Repo.update(returning: true)
      rescue
        # Triggered if someone tried to update the actor for the object
        ex in Postgrex.Error ->
          message = ex.message || ex.postgres.message
          {:error, %Error{code: :update_not_allowed, status: :bad_request, message: message}}
      end
    else
      _ ->
        {:error, "Object %{params.ap_id} not found"}
    end
  end

  def repo_update(:mailboxes, params) do
    Mailbox.changeset(%Mailbox{id: params.ulid}, params) |> Repo.update(returning: true)
  end

  def repo_update(other, _) do
    {:error, "Invalid schema for insert #{other}"}
  end

  def repo_delete(:actors, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = User |> where([u], u.ap_id == ^ap_id)
    Repo.delete_all(query)
  end

  def repo_delete(:activities, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = Activity |> where([a], a.ap_id == ^ap_id)
    Repo.delete_all(query)
  end

  def repo_delete(:objects, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = Object |> where([o], o.ap_id == ^ap_id)
    Repo.delete_all(query)
  end

  def repo_delete(:likes, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = ObjectAction |> where([o], o.object == ^ap_id)
    Repo.delete_all(query)
  end

  def repo_delete(:shares, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = ObjectAction |> where([o], o.object == ^ap_id)
    Repo.delete_all(query)
  end

  def repo_delete(:collections, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = UserCollection |> where([c], c.collection_id == ^ap_id)
    Repo.delete_all(query)
  end

  def repo_delete(other, _) do
    {:error, "Invalid schema for delete #{other}"}
  end

  def describe_errors(
        %Changeset{action: action, data: %{__struct__: module}, errors: errors} = changeset
      ) do
    error_str =
      Enum.map(errors, fn {field, _error_keywords} = error ->
        "#{inspect(error)}"
        # to_string(field)
      end)
      |> Enum.join(", ")

    "#{Utils.alias_module(module)} #{action} error: #{inspect(changeset)}"
    # "#{Utils.alias_module(module)} #{action} error on fields: #{error_str}"
  end

  def dump_file(object, schema, ap_id) do
    case Utils.to_uri(ap_id) |> parse_iri_schema() do
      {:ok, schema, ulid_or_nickname, nil} ->
        path = "#{schema}-#{ulid_or_nickname}.exs"
        Logger.error("Dumping #{path}")
        File.write(path, "#{inspect(Map.from_struct(object))}")

      {:ok, schema, ulid_or_nickname, collection} ->
        path = "#{schema}-#{ulid_or_nickname}-#{collection}.exs"
        Logger.error("Dumping #{path}")
        File.write(path, "#{inspect(Map.from_struct(object))}")

      _ ->
        Logger.error("Couldn't parse #{ap_id}")
        :ok
    end
  end

  def dump_file(_), do: :ok
end
