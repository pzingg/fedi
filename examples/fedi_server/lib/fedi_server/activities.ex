defmodule FediServer.Activities do
  @moduledoc """
  Main context. Handles all ActivityPub actions that interact with
  the database.
  """

  @behaviour Fedi.ActivityPub.DatabaseApi

  import Ecto.Query

  require Logger

  alias Fedi.Streams.Error
  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T

  alias FediServer.Accounts.User
  alias FediServer.Accounts.BlockedAccount
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

  Called from `SideEffectActor.post_inbox/3`.
  """
  @impl true
  def collection_contains?(%URI{path: path} = coll_id, %URI{} = id) do
    with {:ok, %URI{} = actor} <- actor_for_collection(coll_id) do
      coll_name = Path.basename(path)
      collection_contains?(actor, coll_name, id)
    end
  end

  def collection_contains?(%URI{} = actor_iri, coll_name, %URI{} = id) do
    actor_id = URI.to_string(actor_iri)

    query =
      case collection_type(coll_name) do
        {:mailbox, outgoing} ->
          activity_id = URI.to_string(id)

          Mailbox
          |> join(:inner, [c], o in Activity, on: o.ap_id == c.activity_id)
          |> where([c], c.actor == ^actor_id)
          |> where([c], c.outgoing == ^outgoing)
          |> where([c, o], o.ap_id == ^activity_id)

        :following ->
          following_id = URI.to_string(id)

          FollowingRelationship
          |> join(:inner, [c], u in User, on: c.following_id == u.id)
          |> join(:inner, [c], g in User, on: c.follower_id == g.id)
          |> where([c, u, g], g.ap_id == ^actor_id)
          |> where([c, u], u.ap_id == ^following_id)
          |> where([c], c.state == ^:accept)

        :followers ->
          follower_id = URI.to_string(id)

          FollowingRelationship
          |> join(:inner, [c], u in User, on: c.follower_id == u.id)
          |> join(:inner, [c], g in User, on: c.following_id == g.id)
          |> where([c, u, g], g.ap_id == ^actor_id)
          |> where([c, u], u.ap_id == ^follower_id)
          |> where([c], c.state == ^:accept)

        # Special collections, ObjectActions
        _ ->
          nil
      end

    if is_nil(query) do
      {:error, "Can't understand collection #{coll_name}"}
    else
      {:ok, Repo.exists?(query)}
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
      coll_name = Path.basename(path)

      if Keyword.get(opts, :page, false) do
        ordered_collection_page(actor_iri, coll_name, opts)
      else
        ordered_collection_summary(actor_iri, coll_name, opts)
      end
    end
  end

  def get_collection_unfiltered(%URI{path: path} = coll_id) do
    with {:ok, %URI{} = actor_iri} <- actor_for_collection(coll_id) do
      coll_name = Path.basename(path)
      ordered_collection_page(actor_iri, coll_name, unfiltered: true)
    end
  end

  def ordered_collection_summary(actor_iri, coll_name, opts) do
    actor_id = URI.to_string(actor_iri)

    query =
      case collection_type(coll_name) do
        {:mailbox, outgoing} ->
          Mailbox
          |> join(:inner, [c], o in Activity, on: o.ap_id == c.activity_id)
          |> where([c], c.actor == ^actor_id)
          |> where([c], c.outgoing == ^outgoing)
          |> select([c, o], count(o.id))

        {:object_action, type} ->
          ObjectAction
          |> where([o], o.object == ^actor_id)
          |> where([o], o.type == ^type)
          |> select([o], count(o.id))

        :following ->
          FollowingRelationship
          |> where([c], c.follower_id == ^actor_id)
          |> where([c], c.state == ^:accept)
          |> select([c], count(c.id))

        :followers ->
          FollowingRelationship
          |> where([c], c.following_id == ^actor_id)
          |> where([c], c.state == ^:accept)
          |> select([c], count(c.id))

        # Special collections
        {:user_collection, name} ->
          coll_id = Path.join(actor_id, name)

          UserCollection
          |> where([c], c.collection_id == ^coll_id)
          |> select([c], count(c.id))

        _ ->
          nil
      end

    build_summary(query, actor_iri, coll_name, opts)
  end

  def build_summary(nil, _, coll_name, _) do
    {:error, "Can't understand collection #{coll_name}"}
  end

  def build_summary(query, %URI{path: actor_path} = actor_iri, coll_name, _opts) do
    type_prop = Fedi.JSONLD.Property.Type.new_type("OrderedCollection")

    coll_id = %URI{actor_iri | path: Path.join(actor_path, coll_name)}
    id_prop = Fedi.JSONLD.Property.Id.new_id(coll_id)

    first_id = %URI{coll_id | query: "page=true"}
    first_prop = %P.First{alias: "", iri: first_id}

    total_items = Repo.one(query) || 0

    total_items_prop = %P.TotalItems{
      alias: "",
      xsd_non_neg_integer_member: total_items
    }

    properties = %{
      "type" => type_prop,
      "id" => id_prop,
      "first" => first_prop,
      "totalItems" => total_items_prop
    }

    {:ok, %T.OrderedCollectionPage{alias: "", properties: properties}}
  end

  def ordered_collection_page(actor_iri, coll_name, opts) do
    actor_id = URI.to_string(actor_iri)
    page_size = Keyword.get(opts, :page_size, 30)

    query =
      case collection_type(coll_name) do
        {:mailbox, outgoing} ->
          Activity
          |> distinct(true)
          |> join(:inner, [a], c in Mailbox, on: c.activity_id == a.ap_id)
          |> select([a], %{id: a.id, data: a.data})
          |> filter_collection(opts, 2)
          |> where([a, c], c.actor == ^actor_id)
          |> where([a, c], c.outgoing == ^outgoing)
          |> limit(^page_size)
          |> order_by([a], desc: a.id)

        {:object_action, type} ->
          # `actor_id` is really the `object_id`
          object_id = actor_id

          User
          |> join(:inner, [u], c in ObjectAction, on: c.actor == u.ap_id)
          |> select([u], %{id: u.id, data: u.data})
          # TODO should visibility be filtered by the visibilty of `c.object`?
          # |> filter_collection(opts, 2)
          |> where([u, c], c.object == ^object_id)
          |> where([u, c], c.type == ^type)
          |> order_by([u, c], desc: c.activity)
          |> limit(^page_size)

        :following ->
          FollowingRelationship
          |> select([c], %{id: c.id, iri: c.following_id})
          |> where([c], c.follower_id == ^actor_id)
          |> where([c], c.state == ^:accept)
          |> order_by([c], desc: c.id)
          |> limit(^page_size)

        :followers ->
          FollowingRelationship
          |> select([c], %{id: c.id, iri: c.follower_id})
          |> where([c], c.following_id == ^actor_id)
          |> where([c], c.state == ^:accept)
          |> order_by([c], desc: c.id)
          |> limit(^page_size)

        # Special collections
        {:user_collection, name} ->
          coll_id = Path.join(actor_id, name)

          Object
          |> distinct(true)
          |> join(:inner, [o], c in UserCollection, on: c.object == o.ap_id)
          |> where([_o, c], c.collection_id == ^coll_id)
          |> select([o], %{id: o.id, iri: o.ap_id})
          |> filter_collection(opts, 2)
          |> order_by([o], desc: o.id)
          |> limit(^page_size)

        _ ->
          nil
      end

    build_page(query, actor_iri, coll_name, opts)
  end

  def follower?(%URI{} = actor, %URI{} = follower_iri) do
    collection_contains?(actor, "followers", follower_iri)
  end

  def get_following_ids(follower_id) when is_binary(follower_id) do
    FollowingRelationship
    |> where([c], c.follower_id == ^follower_id)
    |> where([c], c.state == ^:accept)
    |> select([c], c.id)
    |> Repo.all()
  end

  def filter_collection(query, opts, arity) when is_list(opts) do
    if Keyword.get(opts, :unfiltered, false) do
      query
    else
      [:min_id, :max_id, :visible_to]
      |> Enum.reduce(query, fn key, q ->
        filter_collection(q, key, Keyword.get(opts, key), arity)
      end)
    end
  end

  def filter_collection(query, :max_id, nil, _), do: query

  def filter_collection(query, :max_id, max_id, _) do
    query |> where([o], o.id < ^max_id)
  end

  def filter_collection(query, :min_id, nil, _), do: query

  def filter_collection(query, :min_id, min_id, _) do
    query |> where([o], o.id >= ^min_id)
  end

  def filter_collection(query, :visible_to, nil, arity) do
    filter_collection_public(query, arity)
  end

  def filter_collection(query, :visible_to, visible_to, arity)
      when is_binary(visible_to) do
    filter_collection_recipients(query, visible_to, arity)
  end

  def filter_collection_recipients(query, ap_id, 1) do
    if ap_id do
      query
      |> join(:left, [o], dr in assoc(o, :direct_recipients))
      |> join(:left, [o, _dr], fr in assoc(o, :following_recipients))
      |> join(:left, [_o, _dr, _fr], fg in FollowingRelationship, on: fg.follower_id == ^ap_id)
      |> filter_collection_public(1)
      |> or_where([_o, dr], dr.address == ^ap_id)
      |> or_where([_o, _dr, fr], fr.address == ^ap_id)
      |> or_where([_o, _dr, fr, fg], fr.address == fg.following_id)
    else
      query
    end
  end

  def filter_collection_recipients(query, ap_id, 2) do
    if ap_id do
      query
      |> join(:left, [o, _c], dr in assoc(o, :direct_recipients))
      |> join(:left, [o, _c, _dr], fr in assoc(o, :following_recipients))
      |> join(:left, [_o, _c, _dr, _fr], fg in FollowingRelationship, on: fg.follower_id == ^ap_id)
      |> filter_collection_public(2)
      |> or_where([_o, _c, dr], dr.address == ^ap_id)
      |> or_where([_o, _c, _dr, fr], fr.address == ^ap_id)
      |> or_where([_o, _c, _dr, fr, fg], fr.address == fg.following_id)
    else
      query
    end
  end

  def debug_sql(query) do
    sql = Repo.to_sql(:all, query)
    Logger.error("sql #{inspect(sql)}")
    query
  end

  def filter_collection_public(query, 1) do
    query |> where([o], o.public? == true)
  end

  def filter_collection_public(query, 2) do
    query |> where([o, _], o.public? == true)
  end

  def collection_type(%URI{path: path} = _coll_id) do
    Path.basename(path) |> collection_type()
  end

  def collection_type(coll_name) when is_binary(coll_name) do
    case coll_name do
      "inbox" -> {:mailbox, false}
      "outbox" -> {:mailbox, true}
      "following" -> :following
      "followers" -> :followers
      "likes" -> {:object_action, "like"}
      "shares" -> {:object_action, "share"}
      other -> {:user_collection, other}
    end
  end

  def build_page(nil, _, coll_name, _) do
    {:error, "Can't understand collection #{coll_name}"}
  end

  def build_page(query, %URI{path: actor_path} = actor_iri, coll_name, _opts) do
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
              Logger.error("For #{coll_name} could not resolve #{inspect(data)}")
              nil
          end

        item ->
          Logger.error("For #{coll_name} don't know how to map #{inspect(item)}")
          nil
      end)
      |> Enum.filter(fn iter -> !is_nil(iter) end)

    ordered_items_prop = %P.OrderedItems{alias: "", values: ordered_item_iters}

    type_prop = Fedi.JSONLD.Property.Type.new_type("OrderedCollectionPage")

    coll_id = %URI{actor_iri | path: Path.join(actor_path, coll_name)}
    part_of_prop = %P.PartOf{alias: "", iri: coll_id}

    page_id = %URI{coll_id | query: "page=true"}
    id_prop = Fedi.JSONLD.Property.Id.new_id(page_id)

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
          next_id = %URI{coll_id | query: "max_id=#{last_id}&page=true"}
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
         coll_name <- Path.basename(path),
         {:valid_type, type} when not is_nil(type) <- {:valid_type, collection_type(coll_name)} do
      to_remove = Map.get(updates, :remove, [])

      case remove_collection_items(type, actor_iri, to_remove) do
        {:error, reason} ->
          {:error, reason}

        _ ->
          to_add = Map.get(updates, :add, [])

          case add_collection_items(type, actor_iri, to_add) do
            {:error, reason} ->
              {:error, reason}

            _ ->
              # For :following type only
              to_update = Map.get(updates, :update, [])
              state = Map.get(updates, :state, :accept)

              case update_collection_items(type, actor_iri, to_update, state) do
                {:error, reason} ->
                  {:error, reason}

                _ ->
                  get_collection(coll_id)
              end
          end
      end
    else
      {:error, reason} -> {:error, reason}
      {:valid_type, _} -> {:error, "Can't understand collection #{coll_id}"}
    end
  end

  def add_collection_items(type, actor_iri, items) do
    Enum.reduce_while(items, [], fn item, acc ->
      add_collection_item(type, actor_iri, item, acc)
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      items ->
        {:ok, items}
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
          local?: params.local?
        })

      case repo_insert(:mailboxes, params) do
        {:ok, %Mailbox{id: id}} ->
          {:cont, [{params.ap_id, id} | acc]}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    else
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  def add_collection_item(
        :following,
        %URI{} = actor_iri,
        %URI{} = following_id,
        acc
      ) do
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

  def add_collection_item({:user_collection, name}, %URI{} = actor_iri, %URI{} = object_id, acc) do
    case repo_get_by_ap_id(:objects, object_id) do
      %Object{type: type} ->
        actor_id = URI.to_string(actor_iri)
        coll_id = Path.join(actor_id, name)

        params = %{
          collection_id: coll_id,
          type: type,
          actor: actor_id,
          object: URI.to_string(object_id)
        }

        case repo_insert(:collections, params) do
          {:ok, %UserCollection{}} -> {:cont, [object_id | acc]}
          {:error, changeset} -> {:halt, {:error, changeset}}
        end

      _ ->
        {:halt, {:error, "Object #{object_id} not found"}}
    end
  end

  def add_collection_item(
        {:object_action, type},
        %URI{} = object_iri,
        {%URI{} = actor_iri, %URI{} = activity_iri},
        acc
      ) do
    Logger.error("#{actor_iri} #{type}d #{object_iri}")
    object_id = URI.to_string(object_iri)
    actor_id = URI.to_string(actor_iri)
    activity_id = URI.to_string(activity_iri)

    params = %{
      type: type,
      actor: actor_id,
      activity: activity_id,
      object: object_id,
      local?: local?(activity_iri)
    }

    case repo_insert({:object_action, type}, params) do
      {:ok, _} ->
        {:cont, [actor_iri | acc]}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  def add_collection_item(type, actor_iri, object_id, _acc) do
    case actor_iri do
      %URI{} ->
        case object_id do
          %URI{} ->
            {:halt, {:error, "Add item unimplemented for #{inspect(type)}"}}

          _ ->
            {:halt, {:error, "Add item: object #{inspect(object_id)} is not a URI"}}
        end

      _ ->
        {:halt, {:error, "Add item: actor #{inspect(actor_iri)} is not a URI"}}
    end
  end

  def update_collection_items(type, actor_iri, items, state) do
    Enum.reduce_while(items, [], fn item, acc ->
      update_collection_item(type, actor_iri, item, state, acc)
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      items ->
        {:ok, items}
    end
  end

  def update_collection_item(
        :following,
        %URI{} = actor_iri,
        %URI{} = following_id,
        state,
        acc
      ) do
    case update_following_relationship(actor_iri, following_id, state) do
      :ok -> {:cont, [following_id | acc]}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  def update_collection_item(type, _actor_id, _item, _state, _acc) do
    Logger.error("Update collection not defined on #{type}")
    {:halt, {:error, "Unimplemented"}}
  end

  def remove_collection_items(_type, _actor_id, []), do: :ok

  def remove_collection_items({:user_collection, name}, %URI{} = actor_iri, object_ids) do
    # TODO dereference to get object_type?
    actor_id = URI.to_string(actor_iri)
    coll_id = Path.join(actor_id, name)
    object_ids = Enum.map(object_ids, &URI.to_string(&1))
    to_delete = Enum.count(object_ids)

    {count_deleted, _} =
      UserCollection
      |> where([c], c.collection_id == ^coll_id)
      |> where([c], c.object in ^object_ids)
      |> Repo.delete_all()

    cond do
      count_deleted == 0 ->
        Logger.error("None of #{to_delete} item(s) were removed from #{coll_id}")
        {:error, "Not found"}

      count_deleted < to_delete ->
        Logger.error("Only #{count_deleted} of #{to_delete} item(s) were removed from #{coll_id}")
        :ok

      true ->
        :ok
    end
  end

  def remove_collection_items(
        {:object_action, type},
        %URI{} = object_iri,
        actor_iris
      ) do
    object_id = URI.to_string(object_iri)
    actor_ids = Enum.map(actor_iris, &URI.to_string(&1))
    to_delete = Enum.count(actor_ids)

    {count_deleted, _} =
      ObjectAction
      |> where([c], c.type == ^type)
      |> where([c], c.object == ^object_id)
      |> where([c], c.actor in ^actor_ids)
      |> Repo.delete_all()

    cond do
      count_deleted == 0 ->
        Logger.error("None of #{to_delete} item(s) were removed from #{object_id} #{type}s")
        {:error, "Not found"}

      count_deleted < to_delete ->
        Logger.error(
          "Only #{count_deleted} of #{to_delete} item(s) were removed from #{object_id} #{type}s"
        )

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
  def actor_for_collection(%URI{path: path} = coll_id) do
    if local?(coll_id) do
      coll_name = Path.basename(path)

      if Enum.member?(["likes", "shares"], coll_name) do
        # Return the object id
        {:ok, Utils.base_uri(coll_id, Path.dirname(path))}
      else
        case parse_iri_schema(coll_id) do
          {:ok, :actors, nickname, _} ->
            # Return the actor id
            {:ok, Utils.base_uri(coll_id, "/users/#{nickname}")}

          {:error, _} ->
            {:error, "Invalid collection #{coll_id}"}
        end
      end
    else
      {:error, "Not our actor #{coll_id}"}
    end
  end

  @doc """
  Fetches the actor's IRI for the given outbox IRI.

  Used in federated SideEffectActor and `like` Activity callbacks.
  """
  @impl true
  def actor_for_outbox(%URI{} = iri) do
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
  def actor_for_inbox(%URI{} = iri) do
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
  def outbox_for_inbox(%URI{} = iri) do
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
  def inbox_for_actor(%URI{path: actor_path} = iri) do
    with true <- local?(iri),
         {:ok, :actors, nickname, nil} <- parse_iri_schema(iri),
         true <- "/users/#{nickname}" == actor_path do
      {:ok, Utils.base_uri(iri, "/users/#{nickname}/inbox")}
    else
      {:ok, _schema, _nickname, _collection} ->
        {:ok, nil}

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
    if local?(ap_id) do
      get_object_data(ap_id)
    else
      with {:error, _reason} <- get_object_data(:objects, ap_id),
           {:error, _reason} <- get_object_data(:activities, ap_id) do
        {:error, "Not found"}
      end
    end
    |> case do
      {:ok, data} ->
        resolve_with_stripped_recipients(data)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_object_data(%URI{} = ap_id) do
    case parse_iri_schema(ap_id) do
      {:ok, :actors, _nickname, coll_name} when is_binary(coll_name) ->
        case get_collection_unfiltered(ap_id) do
          {:ok, oc} ->
            Fedi.Streams.Serializer.serialize(oc)

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, schema, _, _} ->
        get_object_data(schema, ap_id)
    end
  end

  def get_object_data(schema, %URI{} = ap_id) do
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
    with {:ok, params} <- build_params(as_type) do
      case repo_insert(params.schema, params) do
        {:error, reason} ->
          {:error, reason}

        {:ok, _object} ->
          {:ok, as_type, params.data}
      end
    end
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
    with {:ok, params} <- build_params(as_type) do
      case repo_update(params.schema, params) do
        {:error, reason} ->
          {:error, reason}

        {:ok, _object} ->
          {:ok, as_type}
      end
    end
  end

  def build_params(as_type) do
    with {:activity_actor, %URI{} = actor_iri} <-
           {:activity_actor, Utils.get_actor_or_attributed_to_iri(as_type)},
         {:ok, params} <-
           parse_basic_params(as_type),
         {:ok, json_data} <-
           Fedi.Streams.Serializer.serialize(as_type),
         {:ok, recipients} <- APUtils.get_recipients(as_type, empty_ok: true),
         recipient_params <- canonical_recipients(recipients),
         actor_id <- URI.to_string(actor_iri),
         object_id <- URI.to_string(params.ap_id) do
      {:ok,
       params
       |> Map.merge(recipient_params)
       |> Map.merge(%{
         ap_id: object_id,
         actor: actor_id,
         data: json_data
       })}
    else
      {:activity_actor, _} -> {:error, Utils.err_actor_required(activity: as_type)}
    end
  end

  def canonical_recipients(recipients) do
    recipients =
      List.wrap(recipients)
      |> Enum.map(fn
        %URI{} = r -> URI.to_string(r)
        r -> r
      end)

    {public, rest} = Enum.split_with(recipients, &APUtils.public?(&1))
    {following, direct} = Enum.split_with(rest, &String.ends_with?(&1, "/followers"))

    following =
      Enum.map(following, fn addr ->
        %{type: :following, address: String.replace_trailing(addr, "/followers", "")}
      end)

    direct =
      Enum.map(direct, fn addr ->
        %{type: :direct, address: addr}
      end)

    %{
      public?: !Enum.empty?(public),
      direct_recipients: direct,
      following_recipients: following
    }
  end

  def fix_recipient(addr, actor_followers) do
    cond do
      APUtils.public?(addr) -> APUtils.public_activity_streams()
      addr == actor_followers -> [actor_followers, "/:actor:/followers"]
      true -> addr
    end
  end

  def unique_constraint_error(changeset) do
    Enum.find(changeset.errors, fn {_field, {_msg, opts}} ->
      opts[:constraint] == :unique
    end)
  end

  @doc """
  Removes the entry with the given id.

  delete is only called for federated objects. Deletes from the Social
  API should call Update to create a Tombstone.
  """
  @impl true
  def delete(%URI{} = ap_id) do
    with {:objects, {0, _}} <- {:objects, repo_delete(:objects, ap_id)},
         {:activities, {0, _}} <- {:activities, repo_delete(:activities, ap_id)} do
      {:error, "Nothing was deleted"}
    else
      {schema, {n, _}} when is_integer(n) ->
        Logger.debug("Deleted #{n} #{schema} at #{ap_id}")
        :ok
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
  def new_id(as_type) do
    # endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()

    with {:activity_actor, %URI{path: actor_path} = actor_iri} <-
           {:activity_actor, Utils.get_actor_or_attributed_to_iri(as_type)},
         {:local_actor, true} <- {:local_actor, local?(actor_iri)},
         {:ok, _type_name, category} <- Utils.get_type_name_and_category(as_type) do
      ulid = Ecto.ULID.generate()

      case category do
        :actors -> {:error, "Cannot make new id for actors"}
        :activities -> {:ok, %URI{actor_iri | path: actor_path <> "/activities/#{ulid}"}}
        _ -> {:ok, %URI{actor_iri | path: actor_path <> "/objects/#{ulid}"}}
      end
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_actor, _} ->
        Logger.error(
          "Couldn't get attributed_to in object #{Utils.alias_module(as_type.__struct__)}"
        )

        {:error, Utils.err_actor_required(object: as_type)}

      {:local_actor, _} ->
        Logger.error("Actor in object #{Utils.alias_module(as_type.__struct__)} is not ours")
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

  def get_following_relationship(%URI{} = follower_iri, %URI{} = following_iri) do
    follower_id = URI.to_string(follower_iri)
    following_id = URI.to_string(following_iri)

    query =
      FollowingRelationship
      |> where([c], c.follower_id == ^follower_id and c.following_id == ^following_id)

    Repo.one(query)
  end

  def update_following_relationship(%URI{} = follower_iri, %URI{} = following_iri, :reject) do
    unfollow(follower_iri, following_iri)
  end

  def update_following_relationship(%URI{} = follower_iri, %URI{} = following_iri, :accept) do
    follower_id = URI.to_string(follower_iri)
    following_id = URI.to_string(following_iri)

    query =
      FollowingRelationship
      |> where([c], c.follower_id == ^follower_id and c.following_id == ^following_id)

    now = DateTime.utc_now()

    case Repo.update_all(query, set: [state: "accept", updated_at: now]) do
      {0, _} ->
        {:error, "Not found"}

      {_, _} ->
        Logger.error("#{follower_id} follows #{following_id} accept")
        :ok
    end
  end

  def follow(follower_id, following_id, state \\ :accept)

  def follow(%URI{} = follower_iri, %URI{} = following_iri, state) do
    follow(URI.to_string(follower_iri), URI.to_string(following_iri), state)
  end

  def follow(follower_id, following_id, state)
      when is_binary(follower_id) and is_binary(following_id) do
    params = %{
      follower_id: follower_id,
      following_id: following_id,
      state: state
    }

    # TODO Announce?
    result =
      %FollowingRelationship{}
      |> FollowingRelationship.changeset(params)
      |> Repo.insert(on_conflict: :nothing, returning: true)
      |> handle_insert_result(:following)

    case result do
      {:error, reason} ->
        {:error, reason}

      {:ok, data} ->
        Logger.error("#{follower_id} now follows #{following_id} #{state}")
        {:ok, data}
    end
  end

  def unfollow(%URI{} = follower_iri, %URI{} = following_iri) do
    follower_id = URI.to_string(follower_iri)
    following_id = URI.to_string(following_iri)

    query =
      FollowingRelationship
      |> where([c], c.follower_id == ^follower_id and c.following_id == ^following_id)

    case Repo.delete_all(query) do
      {0, _} ->
        {:error, "Not found"}

      {_, _} ->
        Logger.error("#{follower_id} no longer follows #{following_id}")

        :ok
    end
  end

  def block(%User{} = actor, %URI{} = blocked_id) do
    BlockedAccount.build_block(actor, blocked_id)
    |> Repo.insert()
    |> handle_insert_result(:blocked_account)
  end

  def unblock(%User{id: user_id} = _actor, %URI{} = blocked_id) do
    blocked_id = URI.to_string(blocked_id)

    query =
      BlockedAccount
      |> where([b], b.user_id == ^user_id and b.ap_id == ^blocked_id)

    case Repo.delete_all(query) do
      {0, _} -> {:error, "Not found"}
      {_, _} -> :ok
    end
  end

  def any_blocked?(%User{id: user_id} = _actor, actor_iris) do
    blocked_ids = Enum.map(actor_iris, fn %URI{} = id -> URI.to_string(id) end)

    BlockedAccount
    |> where([b], b.user_id == ^user_id and b.ap_id in ^blocked_ids)
    |> Repo.exists?()
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
  def iri_exists?(%URI{} = iri) do
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
  def get_by_iri(%URI{} = iri) do
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
                 local?: true,
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
                 local?: false,
                 type: type_name
               }}
            end

          {:ok, _, schema} ->
            Logger.debug("Parsed #{Utils.alias_module(as_type.__struct__)} as ERROR #{schema}")
            {:error, "Bad schema #{schema} for #{type_name}"}
        end

      {:ok, ap_id, type_name, category} ->
        params =
          if category == :activities || category == :collections do
            %{
              schema: category,
              ap_id: ap_id,
              ulid: nil,
              nickname: nil,
              local?: local?(ap_id),
              type: type_name
            }
          else
            in_reply_to =
              case Utils.get_iri(as_type, "inReplyTo") do
                %URI{} = iri -> URI.to_string(iri)
                _ -> nil
              end

            %{
              schema: :objects,
              ap_id: ap_id,
              ulid: nil,
              nickname: nil,
              in_reply_to: in_reply_to,
              local?: local?(ap_id),
              type: type_name
            }
          end

        {:ok, params}
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
          [_match, nickname, _, collection_suffix] ->
            {:ok, :actors, nickname, collection_suffix}

          [_match, nickname, _] ->
            {:ok, :actors, nickname, nil}

          _ ->
            Logger.error("Failed to parse #{iri}")
            {:error, "Missing schema in #{iri}"}
        end
    end
  end

  def ensure_user(%URI{} = ap_id, local?, app_agent \\ nil) do
    case repo_get_by_ap_id(:actors, ap_id) do
      %User{} = user ->
        {:ok, user}

      _ ->
        if local? do
          {:error, "Local user #{ap_id} not found"}
        else
          resolve_and_insert_user(ap_id, app_agent)
        end
    end
  end

  def resolve_and_insert_user(%URI{} = ap_id, app_agent \\ nil) do
    app_agent = app_agent || FediServer.Application.app_agent()

    with client <- HTTPClient.anonymous(app_agent),
         {:ok, json_body} <- HTTPClient.fetch_masto_user(client, ap_id),
         {:ok, data} <- Jason.decode(json_body),
         %User{} = user <- User.new_remote_user(data),
         {:ok, %User{} = user} <- User.changeset(user) |> Repo.insert(returning: true) do
      {:ok, user}
    else
      {:error, %Ecto.Changeset{}} ->
        {:error, "Could not insert user #{ap_id}"}

      {:error, reason} ->
        {:error, reason}
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

  def repo_get(which, id_value, opts \\ [])

  def repo_get(:actors, nickname, _opts) do
    Repo.get_by(User, nickname: nickname)
  end

  def repo_get(:activities, ulid, opts) do
    Repo.get(Activity, ulid) |> maybe_filter_object(opts)
  end

  def repo_get(:objects, ulid, opts) do
    Repo.get(Object, ulid) |> maybe_filter_object(opts)
  end

  def repo_get(:collections, ulid, opts) do
    case Repo.get(UserCollection, ulid) do
      %UserCollection{object: object_id} ->
        repo_get_by_ap_id(:objects, object_id)
        |> maybe_filter_object(opts)

      _ ->
        nil
    end
  end

  def repo_get(other, _, _) do
    {:error, "Invalid schema for get #{other}"}
  end

  def maybe_filter_object(%{public?: true} = object, _opts), do: object

  def maybe_filter_object(%{public?: _} = object, opts) do
    case Keyword.get(opts, :visible_to) do
      ap_id when is_binary(ap_id) ->
        object
        |> Repo.preload([:direct_recipients, :following_recipients])
        |> filter_visibility(ap_id)

      _ ->
        nil
    end
  end

  def maybe_filter_object(_, _), do: nil

  def filter_visibility(
        %{direct_recipients: direct_recipients, following_recipients: following_recipients} =
          object,
        viewer
      )
      when is_list(direct_recipients) and is_list(following_recipients) and is_binary(viewer) do
    direct_recipients = Enum.map(direct_recipients, &Map.get(&1, :address))
    following_recipients = Enum.map(following_recipients, &Map.get(&1, :address))

    if Enum.member?(direct_recipients ++ following_recipients, viewer) do
      # Logger.error("visible: direct")
      object
    else
      query =
        FollowingRelationship
        |> where([r], r.follower_id == ^viewer)
        |> where([r], r.following_id in ^following_recipients)

      if Repo.exists?(query) do
        # Logger.error("visible: follower")
        object
      else
        # Logger.error("invisible")
        nil
      end
    end
  end

  def filter_visibility(_, _), do: nil

  def repo_get_by_ap_id(:actors, %URI{} = ap_id) do
    Repo.get_by(User, ap_id: URI.to_string(ap_id))
  end

  def repo_get_by_ap_id(:activities, %URI{} = ap_id) do
    Repo.get_by(Activity, ap_id: URI.to_string(ap_id))
    |> Repo.preload([:direct_recipients, :following_recipients])
  end

  def repo_get_by_ap_id(:objects, %URI{} = ap_id) do
    Repo.get_by(Object, ap_id: URI.to_string(ap_id))
    |> Repo.preload([:direct_recipients, :following_recipients])
  end

  def repo_get_by_ap_id(:followers, %URI{} = ap_id) do
    Repo.get_by(Object, ap_id: URI.to_string(ap_id))
  end

  def repo_get_by_ap_id(:following, %URI{} = ap_id) do
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

  def repo_insert({:object_action, type}, params) do
    Logger.debug("Inserting #{type}: #{params.object}")

    ObjectAction.changeset(%ObjectAction{}, Map.put(params, :type, type))
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
      Logger.debug("Conflict on insert #{type}: #{inspect(changeset)}")
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
    with %Activity{} = activity <- repo_get_by_ap_id(:activities, URI.parse(params.ap_id)) do
      Activity.changeset(activity, params) |> Repo.update(returning: true)
    else
      _ ->
        {:error, "Activity %{params.ap_id} not found"}
    end
  end

  def repo_update(:objects, params) do
    with %Object{} = object <- repo_get_by_ap_id(:objects, URI.parse(params.ap_id)) do
      try do
        Object.changeset(object, params) |> Repo.update(returning: true)
      rescue
        # Triggered if someone tried to update the actor for the object
        ex in Postgrex.Error ->
          message = ex.message || ex.postgres.message

          {:error,
           %Error{code: :update_not_allowed, status: :unprocessable_entity, message: message}}
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

  def repo_delete(:collections, %URI{} = ap_id) do
    ap_id = URI.to_string(ap_id)
    query = UserCollection |> where([c], c.collection_id == ^ap_id)
    Repo.delete_all(query)
  end

  def repo_delete(other, _) do
    {:error, "Invalid schema for delete #{other}"}
  end

  def describe_errors(%Ecto.Changeset{action: action, data: %{__struct__: module}} = changeset) do
    error_str =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)
      |> Map.to_list()
      |> Enum.map(fn {field, msg} -> "#{field} #{msg}" end)
      |> Enum.join(", ")

    "#{Utils.alias_module(module)} #{action} error: #{error_str}"
  end

  def dump_file(object, ap_id) do
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
end
