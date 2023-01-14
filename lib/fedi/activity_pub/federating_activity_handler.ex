defmodule Fedi.ActivityPub.FederatingActivityHandler do
  @moduledoc """
  Callback functions that already have some side effect behavior.
  """

  @behaviour Fedi.ActivityPub.FederatingActivityApi

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T
  alias Fedi.ActivityPub.Actor
  alias Fedi.ActivityPub.Utils, as: APUtils

  @doc """
  Implements the federating Create activity side effects.
  """
  def create(%{database: database} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, created} when is_list(created) <- create_objects(context, values),
         {:ok, _created, _raw_json} <- apply(database, :create, [activity]) do
      Actor.handle_activity(context, :s2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  def create_objects(
        %{data: %{box_iri: inbox_iri, app_agent: app_agent}, database: database},
        values
      )
      when is_list(values) do
    Enum.reduce_while(values, [], fn
      %{member: as_type}, acc when is_struct(as_type) ->
        case apply(database, :create, [as_type]) do
          {:ok, created, _raw_json} ->
            {:cont, [created | acc]}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end

      %{iri: %URI{} = iri}, acc ->
        with {:ok, m} <- apply(database, :dereference, [inbox_iri, app_agent, iri]),
             {:ok, as_type} <- Fedi.Streams.JSONResolver.resolve(m) do
          case apply(database, :create, [as_type]) do
            {:ok, created, _raw_json} ->
              {:cont, [created | acc]}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end

      _, _ ->
        {:halt, {:error, "Cannot handle federated create: object is neither a value nor IRI"}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      created -> {:ok, Enum.reverse(created)}
    end
  end

  @doc """
  Implements the federating Update activity side effects.
  """
  def update(%{database: database} = _context, activity) when is_struct(activity) do
    with {:ok, %{values: values}} <-
           APUtils.objects_match_activity_origin?(activity),
         {:ok, _updated} <-
           update_objects(database, values),
         {:ok, updated, _raw_json} <-
           apply(database, :update, [activity]) do
      {:ok, updated}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def update_objects(database, values) do
    Enum.reduce_while(values, [], fn
      %{member: as_type}, acc when is_struct(as_type) ->
        case apply(database, :update, [as_type]) do
          {:ok, updated, _raw_json} -> {:cont, [updated | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      _, _ ->
        {:halt, {:error, "Update requires an object to be wholly provided"}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      updated -> {:ok, Enum.reverse(updated)}
    end
  end

  @doc """
  Implements the federating Delete activity side effects.
  """
  def delete(%{database: database} = context, activity) when is_struct(activity) do
    with {:ok, %{values: values}} <- APUtils.objects_match_activity_origin?(activity),
         {:ok, _deleted} <- delete_objects(database, values),
         {:ok, _} <- apply(database, :delete, [activity]) do
      Actor.handle_activity(context, :s2s, activity)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_objects(database, values) do
    Enum.reduce_while(values, [], fn
      %{member: as_type}, acc when is_struct(as_type) ->
        case apply(database, :delete, [as_type]) do
          {:ok, deleted} -> {:cont, [deleted | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      _, _ ->
        {:halt, {:error, "Update requires an object to be wholly provided"}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      deleted -> {:ok, Enum.reverse(deleted)}
    end
  end

  @doc """
  Implements the federating Follow activity side effects.

  The :on_follow element in the wrapped callback data
  Enumerates the different default actions that the
  library can provide when receiving a Follow Activity from a peer.

  * :do_nothing does not take any action when a Follow Activity
   is received.
  * :automatically_accept triggers the side effect of sending an
   Accept of this Follow request in response.
  * :automatically_reject triggers the side effect of sending a
   Reject of this Follow request in response.
  """
  def follow(
        %{database: database, data: %{on_follow: on_follow, inbox_iri: inbox_iri}} = context,
        %{__struct__: _, alias: alias_} = activity
      ) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, %URI{} = actor_iri} <- apply(database, :actor_for_inbox, [inbox_iri]) do
      case is_me?(values, actor_iri, on_follow != :do_nothing) do
        {:error, reason} ->
          {:error, reason}

        true ->
          case prepare_and_deliver_follow(context, activity, actor_iri, on_follow, alias_) do
            {:error, reason} ->
              {:error, reason}

            _ ->
              Actor.handle_activity(context, :s2s, activity)
          end

        _ ->
          Actor.handle_activity(context, :s2s, activity)
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  def is_me?(actor_iters, actor_iri, enabled \\ true)

  def is_me?(_actor_iters, _actor_iri, false), do: false

  def is_me?(actor_iters, %URI{} = actor_iri, _) when is_list(actor_iters) do
    actor_iri_str = URI.to_string(actor_iri)

    Enum.reduce_while(actor_iters, false, fn prop, acc ->
      case APUtils.to_id(prop) do
        %URI{} = id ->
          if URI.to_string(id) == actor_iri_str do
            {:halt, true}
          else
            {:cont, acc}
          end

        _ ->
          {:halt, {:error, Utils.err_id_required(iters: actor_iters)}}
      end
    end)
  end

  def prepare_and_deliver_follow(
        %{database: database, data: %{box_iri: _box_iri}} = context,
        follow,
        actor_iri,
        on_follow,
        alias_
      ) do
    # Prepare the response
    response =
      case on_follow do
        :automatically_accept ->
          %T.Accept{alias: alias_}

        :automatically_reject ->
          %T.Reject{alias: alias_}

        _ ->
          {:error, "Invalid `on_follow` behavior #{on_follow}"}
      end

    # Set us as the 'actor'.
    me = %P.Actor{alias: alias_} |> Utils.append_iri(actor_iri)

    # Set the Follow as the 'object' property.
    object = %P.Object{
      alias: alias_,
      values: [%P.ObjectIterator{alias: alias_, member: follow}]
    }

    # Add all actors on the original Follow to the 'to' property.
    with {:follow_actor, %{values: _} = actor_prop} when is_struct(actor_prop) <-
           {:follow_actor, Utils.get_actor(follow)},
         {:ok, recipients} <- APUtils.get_recipients(actor_prop, which: :to_only) do
      to_iters =
        Enum.map(recipients, fn iri ->
          %P.ToIterator{alias: alias_, iri: iri}
        end)

      to = %P.To{alias: alias_, values: to_iters}
      response = struct(response, properties: %{"actor" => me, "object" => object, "to" => to})

      if on_follow == :automatically_accept do
        # If automatically accepting, then also update our
        # followers collection with the new actors.

        # If automatically rejecting, do not update the
        # followers collection.
        update_collection(database, :followers, actor_iri, recipients, alias_)
      else
        :ok
      end
      |> case do
        {:error, reason} -> {:error, reason}
        _ -> Actor.delegate(context, :s2s, :deliver, [response])
      end
    else
      {:error, reason} -> {:error, reason}
      {:follow_actor, _} -> {:error, "No actor in Follow activity"}
    end
  end

  def update_collection(database, collection, actor_iri, recipients, alias_) do
    with {:ok, %{properties: _} = coll} <- apply(database, collection, [actor_iri]),
         # Prepend recipients to "items"
         items_iters <-
           Enum.map(recipients, fn iri ->
             %P.ItemsIterator{alias: alias_, iri: iri}
           end),
         coll <- Utils.prepend_iters(coll, "items", items_iters),
         {:ok, updated, _raw_json} <- apply(database, :update, [coll]) do
      {:ok, updated}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Implements the federating Accept activity side effects.
  """
  def accept(%{database: database, inbox_iri: inbox_iri} = context, %{alias: alias_} = activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, actor_iri} <-
           apply(database, :actor_for_inbox, [inbox_iri]),
         # Determine if we are in a follow on the 'object' property.
         # TODO Handle Accept multiple Follow
         {:ok, _follow, follow_id} <-
           find_follow(context, values, actor_iri),
         # If we received an Accept whose 'object' is a Follow with an
         # Accept that we sent, add to the following collection.

         # Verify our Follow request exists and the peer didn't
         # fabricate it.
         {:activity_actor, %P.Actor{values: [_ | _]} = actor_prop} <-
           {:activity_actor, Utils.get_actor(activity)},
         # This may be a duplicate check if we dereferenced the
         # Follow above.
         # TODO Separate this logic to avoid redundancy
         {:ok, follow} <-
           apply(database, :get, [follow_id]),
         # Ensure that we are one of the actors on the Follow.
         {:ok, %URI{}} <-
           follow_is_me?(follow, actor_iri),
         # Build map of original Accept actors
         {:ok, accept_actors} <-
           APUtils.get_ids(actor_prop),
         # Verify all actor(s) were on the original Follow.
         {:follow_object, %{values: [_ | _]} = follow_prop} <-
           {:follow_object, Utils.get_object(follow)},
         {:ok, follow_actors} <-
           APUtils.get_ids(follow_prop),
         {:all_on_original, true} <-
           {:all_on_original,
            MapSet.subset?(MapSet.new(accept_actors), MapSet.new(follow_actors))},
         {:ok, _} <-
           update_collection(database, :following, actor_iri, accept_actors, alias_) do
      Actor.handle_activity(context, :s2s, activity)
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_object, _} ->
        Utils.err_object_required(activity: activity)

      {:activity_actor, _} ->
        Utils.err_actor_required(activity: activity)

      {:follow_object, _} ->
        {:error, "No object in original Follow activity"}

      {:all_on_original, _} ->
        {:error,
         "Peer gave an Accept wrapping a Follow but was not an object in the original Follow"}
    end
  end

  def find_follow(
        %{data: %{box_iri: inbox_iri, app_agent: app_agent}, database: database},
        values,
        %URI{} = actor_iri
      ) do
    Enum.reduce_while(values, {:error, "Not found"}, fn
      # Attempt to dereference the IRI instead
      %{iri: %URI{} = iri}, acc ->
        with {:ok, m} <- apply(database, :dereference, [inbox_iri, app_agent, iri]),
             {:ok, as_type} <- Fedi.Streams.JSONResolver.resolve(m) do
          case follow_is_me?(as_type, actor_iri) do
            {:error, reason} -> {:halt, {:error, reason}}
            {:ok, %URI{} = follow_id} -> {:halt, {:ok, as_type, follow_id}}
            _ -> {:cont, acc}
          end
        else
          _ ->
            {:halt, {:error, "Unable to dereference a valid follow activity"}}
        end

      %{member: as_type}, acc when is_struct(as_type) ->
        case follow_is_me?(as_type, actor_iri) do
          {:error, reason} -> {:halt, {:error, reason}}
          {:ok, %URI{} = follow_id} -> {:halt, {:ok, as_type, follow_id}}
          _ -> {:cont, acc}
        end

      _, _ ->
        {:halt, {:error, "Invalid follow activity"}}
    end)
  end

  def follow_is_me?(as_type, actor_iri) do
    with true <- APUtils.is_or_extends?(as_type, "Follow"),
         %URI{} = follow_id <- APUtils.get_id(as_type),
         %{values: values} when is_list(values) <- Utils.get_actor(as_type) do
      case is_me?(values, actor_iri) do
        {:error, reason} -> {:error, reason}
        true -> {:ok, follow_id}
        _ -> {:ok, nil}
      end
    else
      _ ->
        {:error, "Not a follow type"}
    end
  end

  @doc """
  Implements the federating Reject activity side effects.
  """
  def reject(context, activity) when is_struct(context) and is_struct(activity) do
    Actor.handle_activity(context, :s2s, activity)
  end

  @doc """
  Implements the federating Add activity side effects.
  """
  def add(%{database: database} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_target, %P.Target{values: [_ | _]} = target} <-
           {:activity_target, Utils.get_target(activity)},
         :ok <- APUtils.add(database, object, target) do
      Actor.handle_activity(context, :s2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_target, _} -> Utils.err_target_required(activity: activity)
    end
  end

  @doc """
  Implements the federating Remove activity side effects.
  """
  def remove(%{database: database} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_target, %P.Target{values: [_ | _]} = target} <-
           {:activity_target, Utils.get_target(activity)},
         :ok <- APUtils.remove(database, object, target) do
      Actor.handle_activity(context, :s2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_target, _} -> Utils.err_target_required(activity: activity)
    end
  end

  @doc """
  Implements the federating Like activity side effects.
  """
  def like(%{database: database} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object_prop} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_id, %URI{} = id} <-
           {:activity_id, APUtils.get_id(activity)},
         {:ok, op_ids} <-
           APUtils.get_ids(object_prop) do
      Enum.reduce_while(op_ids, :ok, fn obj_id, acc ->
        with {:owns, {:ok, true}} <- {:owns, apply(database, :owns, [obj_id])},
             {:ok, %{alias: alias_, properties: properties} = like} <-
               apply(database, :get, [obj_id]) do
          # Get 'likes' property on the object, creating default if
          # necessary.
          # Get 'likes' value, defaulting to a collection.
          {prop, col} =
            case Map.get(properties, "likes") do
              %P.Likes{member: col} = likes when is_struct(col) ->
                {likes, col}

              _ ->
                {%P.Likes{alias: alias_}, %T.Collection{alias: alias_}}
            end

          # Prepend the activity's 'id' on the 'likes' Collection or
          # OrderedCollection.
          col =
            case col do
              %T.Collection{} ->
                Utils.prepend_iris(col, "items", [id])

              %T.OrderedCollection{} ->
                Utils.prepend_iris(col, "orderedItems", [id])

              _ ->
                {:error, "Likes type is neither a Collection nor an OrderedCollection"}
            end

          with col when is_struct(col) <- col,
               prop <- struct(prop, member: col),
               like <- struct(like, properties: Map.put(properties, "likes", prop)),
               {:ok, _updated, _raw_json} <- apply(database, :update, [like]) do
            {:cont, acc}
          else
            {:error, reason} -> {:halt, {:error, reason}}
          end
        else
          {:owns, {:ok, _}} -> {:cont, acc}
          {_, {:error, reason}} -> {:halt, {:error, reason}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        _ -> Actor.handle_activity(context, :s2s, activity)
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_id, _} -> Utils.err_id_required(activity: activity)
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  @doc """
  Implements the federating Announce activity side effects.
  """
  def announce(%{database: database} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object_prop} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_id, %URI{} = id} <-
           {:activity_id, APUtils.get_id(activity)},
         {:ok, op_ids} <-
           APUtils.get_ids(object_prop) do
      Enum.reduce_while(op_ids, :ok, fn obj_id, acc ->
        with {:owns, {:ok, true}} <- {:owns, apply(database, :owns, [obj_id])},
             {:ok, %{alias: alias_, properties: properties} = share} <-
               apply(database, :get, [obj_id]) do
          # Get 'shares' property on the object, creating default if
          # necessary.
          # Get 'shares' value, defaulting to a collection.
          {prop, col} =
            case Map.get(properties, "shares") do
              %P.Shares{member: col} = shares when is_struct(col) ->
                {shares, col}

              _ ->
                {%P.Shares{alias: alias_}, %T.Collection{alias: alias_}}
            end

          # Prepend the activity's 'id' on the 'shares' Collection or
          # OrderedCollection.
          col =
            case col do
              %T.Collection{} ->
                Utils.prepend_iris(col, "items", [id])

              %T.OrderedCollection{} ->
                Utils.prepend_iris(col, "orderedItems", [id])

              _ ->
                {:error, "Shares type is neither a Collection nor an OrderedCollection"}
            end

          with col when is_struct(col) <- col,
               prop <- struct(prop, member: col),
               share <- struct(share, properties: Map.put(properties, "shares", prop)),
               {:ok, _updated, _raw_json} <- apply(database, :update, [share]) do
            {:cont, acc}
          else
            {:error, reason} -> {:halt, {:error, reason}}
          end
        else
          {:owns, {:ok, _}} -> {:cont, acc}
          {_, {:error, reason}} -> {:halt, {:error, reason}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        _ -> Actor.handle_activity(context, :s2s, activity)
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_id, _} -> Utils.err_id_required(activity: activity)
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  @doc """
  Implements the federating Undo activity side effects.
  """
  def undo(context, activity) when is_struct(activity) do
    with :ok <- APUtils.object_actors_match_activity_actors?(context, activity) do
      Actor.handle_activity(context, :s2s, activity)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Implements the federating Block activity side effects.
  """
  def block(context, activity)
      when is_struct(context) and is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]}} <-
           {:activity_object, Utils.get_object(activity)} do
      Actor.handle_activity(context, :s2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end
end
