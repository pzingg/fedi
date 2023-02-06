defmodule Fedi.ActivityPub.FederatingActivityHandler do
  @moduledoc """
  Callback functions that already have some side effect behavior.
  """

  @behaviour Fedi.ActivityPub.FederatingActivityApi

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T
  alias Fedi.ActivityPub.ActorFacade
  alias Fedi.ActivityPub.Utils, as: APUtils

  @doc """
  Implements the federating Create activity side effects.
  """
  @impl true
  def create(context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, created} when is_list(created) <- create_objects(context, values),
         {:ok, _created, _raw_json} <- ActorFacade.db_create(context, activity) do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  def create_objects(
        %{box_iri: %URI{}} = context,
        values
      )
      when is_list(values) do
    Enum.reduce_while(values, [], fn
      %{member: as_type}, acc when is_struct(as_type) ->
        case ActorFacade.db_create(context, as_type) do
          {:ok, created, _raw_json} ->
            {:cont, [created | acc]}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end

      %{iri: %URI{} = iri}, acc ->
        with {:ok, m} <- ActorFacade.db_dereference(context, iri),
             {:ok, as_type} <- Fedi.Streams.JSONResolver.resolve(m) do
          case ActorFacade.db_create(context, as_type) do
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
  @impl true
  def update(context, activity) when is_struct(activity) do
    with {:ok, %{values: values}} <-
           APUtils.objects_match_activity_origin?(activity),
         {:ok, _updated} <-
           update_objects(context, values),
         {:ok, _updated} <-
           ActorFacade.db_update(context, activity) do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def update_objects(context, values) do
    Enum.reduce_while(values, [], fn
      %{member: as_type}, acc when is_struct(as_type) ->
        case ActorFacade.db_update(context, as_type) do
          {:ok, updated} -> {:cont, [updated | acc]}
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
  @impl true
  def delete(context, activity) when is_struct(activity) do
    with {:ok, %{values: values}} <- APUtils.objects_match_activity_origin?(activity),
         :ok <- delete_objects(context, values) do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_objects(context, values) do
    Enum.reduce_while(values, :ok, fn prop, acc ->
      case APUtils.to_id(prop) do
        %URI{} = id ->
          case ActorFacade.db_delete(context, id) do
            :ok -> {:cont, acc}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        nil ->
          {:halt, {:error, Utils.err_id_required(property: prop)}}
      end
    end)
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
  @impl true
  def follow(
        %{on_follow: on_follow, box_iri: %URI{} = inbox_iri} = context,
        %{__struct__: _, alias: alias_} = activity
      ) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, %URI{} = actor_iri} <- ActorFacade.db_actor_for_inbox(context, inbox_iri) do
      case APUtils.is_me?(values, actor_iri, on_follow != :do_nothing) do
        {:error, reason} ->
          {:error, reason}

        true ->
          case prepare_and_deliver_follow(context, activity, actor_iri, on_follow, alias_) do
            {:error, reason} ->
              {:error, reason}

            _ ->
              ActorFacade.handle_s2s_activity(context, activity)
          end

        _ ->
          ActorFacade.handle_s2s_activity(context, activity)
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  def prepare_and_deliver_follow(
        %{box_iri: inbox_iri} = context,
        follow,
        %URI{path: actor_path} = actor_iri,
        on_follow,
        alias_
      ) do
    # Prepare the response
    case on_follow do
      :automatically_accept ->
        {:ok, T.Accept.new(alias: alias_, context: :simple)}

      :automatically_reject ->
        {:ok, T.Reject.new(alias: alias_, context: :simple)}

      _ ->
        {:error, "Invalid 'on_follow' behavior #{on_follow}"}
    end
    |> case do
      {:error, reason} ->
        {:error, reason}

      {:ok, %{properties: resp_properties} = response} ->
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
             {:ok, recipients} <- APUtils.get_ids(actor_prop) do
          to_iters =
            Enum.map(recipients, fn iri ->
              %P.ToIterator{alias: alias_, iri: iri}
            end)

          to = %P.To{alias: alias_, values: to_iters}

          response =
            struct(response,
              properties:
                Map.merge(resp_properties, %{"actor" => me, "object" => object, "to" => to})
            )

          if on_follow == :automatically_accept do
            # If automatically accepting, then also update our
            # followers collection with the new actors.

            # If automatically rejecting, do not update the
            # followers collection.
            coll_id = %URI{actor_iri | path: actor_path <> "/followers"}

            case ActorFacade.db_update_collection(context, coll_id, %{add: recipients}) do
              {:ok, _} -> :ok
              {:error, reason} -> {:error, reason}
            end
          else
            :ok
          end
          |> case do
            {:error, reason} ->
              {:error, reason}

            _ ->
              with {:ok, outbox_iri} <- ActorFacade.db_outbox_for_inbox(context, inbox_iri),
                   {:ok, response} <- ActorFacade.add_new_ids(context, response) do
                ActorFacade.deliver(context, outbox_iri, response)
              else
                {:error, reason} -> {:error, reason}
              end
          end
        else
          {:error, reason} -> {:error, reason}
          {:follow_actor, _} -> {:error, "No actor in Follow activity"}
        end
    end
  end

  @doc """
  Implements the federating Accept activity side effects.
  """
  @impl true
  def accept(context, activity)
      when is_struct(activity) do
    with {:ok, %URI{path: actor_path} = actor_iri, accept_actors} <-
           APUtils.validate_accept_or_reject(context, activity),
         coll_id <- %URI{actor_iri | path: actor_path <> "/following"},
         {:ok, _} <-
           ActorFacade.db_update_collection(context, coll_id, %{
             update: accept_actors,
             state: :accept
           }) do
      ActorFacade.handle_s2s_activity(context, activity)
    end
  end

  @doc """
  Implements the federating Reject activity side effects.
  """
  @impl true
  def reject(context, activity) when is_struct(context) and is_struct(activity) do
    with {:ok, %URI{path: actor_path} = actor_iri, reject_actors} <-
           APUtils.validate_accept_or_reject(context, activity),
         coll_id <- %URI{actor_iri | path: actor_path <> "/following"},
         {:ok, _} <-
           ActorFacade.db_update_collection(context, coll_id, %{
             update: reject_actors,
             state: :reject
           }) do
      ActorFacade.handle_s2s_activity(context, activity)
    end
  end

  @doc """
  Implements the federating Add activity side effects.
  """
  @impl true
  def add(context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_target, %P.Target{values: [_ | _]} = target} <-
           {:activity_target, Utils.get_target(activity)},
         :ok <- APUtils.add(context, object, target) do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_target, _} -> Utils.err_target_required(activity: activity)
    end
  end

  @doc """
  Implements the federating Remove activity side effects.
  """
  @impl true
  def remove(context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_target, %P.Target{values: [_ | _]} = target} <-
           {:activity_target, Utils.get_target(activity)},
         :ok <- APUtils.remove(context, object, target) do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_target, _} -> Utils.err_target_required(activity: activity)
    end
  end

  @doc """
  Implements the federating Like activity side effects.
  """
  @impl true
  def like(context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object_prop} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_actor, %URI{} = actor_iri} <-
           {:activity_actor, Utils.get_actor_or_attributed_to_iri(activity)},
         {:activity_id, %URI{} = activity_id} <-
           {:activity_id, APUtils.get_id(activity)},
         {:ok, object_ids} <-
           APUtils.get_ids(object_prop),
         {:ok, object_ids} <-
           filter_owned_objects(context, object_ids),
         :ok <-
           update_object_collections(context, actor_iri, activity_id, object_ids, "likes") do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_actor, _} -> Utils.err_actor_required(activity: activity)
      {:activity_id, _} -> Utils.err_id_required(activity: activity)
    end
  end

  @doc """
  Implements the federating Announce activity side effects.
  """
  @impl true
  def announce(context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object_prop} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_actor, %URI{} = actor_iri} <-
           {:activity_actor, Utils.get_actor_or_attributed_to_iri(activity)},
         {:activity_id, %URI{} = activity_id} <-
           {:activity_id, APUtils.get_id(activity)},
         {:ok, object_ids} <-
           APUtils.get_ids(object_prop),
         {:ok, object_ids} <-
           filter_owned_objects(context, object_ids),
         :ok <-
           update_object_collections(context, actor_iri, activity_id, object_ids, "shares") do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_actor, _} -> Utils.err_actor_required(activity: activity)
      {:activity_id, _} -> Utils.err_id_required(activity: activity)
    end
  end

  def filter_owned_objects(context, object_ids) do
    Enum.reduce_while(object_ids, [], fn object_id, acc ->
      case ActorFacade.db_owns?(context, object_id) do
        {:ok, true} -> {:cont, [object_id | acc]}
        {:ok, _} -> {:cont, acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      filtered_ids -> {:ok, Enum.reverse(filtered_ids)}
    end
  end

  def update_object_collections(context, actor_iri, activity_id, object_ids, coll_name) do
    Enum.reduce_while(object_ids, :ok, fn %URI{path: object_path} = object_id, acc ->
      coll_id = %URI{object_id | path: Path.join(object_path, coll_name)}

      case ActorFacade.db_update_collection(context, coll_id, %{add: [{actor_iri, activity_id}]}) do
        {:error, reason} -> {:halt, {:error, reason}}
        _ -> {:cont, acc}
      end
    end)
  end

  @doc """
  Implements the federating Undo activity side effects.
  """
  @impl true
  def undo(context, activity) when is_struct(activity) do
    with :ok <- APUtils.object_actors_match_activity_actors?(context, activity) do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Implements the federating Block activity side effects.
  """
  @impl true
  def block(context, activity)
      when is_struct(context) and is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]}} <-
           {:activity_object, Utils.get_object(activity)} do
      ActorFacade.handle_s2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end
end
