defmodule Fedi.ActivityPub.SocialActivityHandler do
  @moduledoc """
  Callback functions that already have some side effect behavior.
  """

  @behaviour Fedi.ActivityPub.SocialActivityApi

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityPub.ActorFacade

  @doc """
  Implements the social Create activity side effects.

  The wrapping callback copies the actor(s) to the 'attributedTo'
  property and copies recipients between the Create activity and all
  objects. It then saves the entry in the database.

  Ref: [AP Section 6.1](https://w3.org/TR/activitypub/#client-addressing)
  Clients submitting the following activities to an outbox MUST provide
  the object property in the activity: Create, Update, Delete, Follow,
  Add, Remove, Like, Block, Undo.

  Ref: [AP Section 6.2](https://www.w3.org/TR/activitypub/#create-activity-outbox)
  When a Create activity is posted, the actor of the activity SHOULD be
  copied onto the object's 'attributedTo' field.

  A mismatch between addressing of the Create activity and its object is
  likely to lead to confusion. As such, a server SHOULD copy any recipients
  of the Create activity to its object upon initial distribution, and
  likewise with copying recipients from the object to the wrapping Create
  activity.
  """
  @impl true
  def create(
        context,
        %{alias: alias_, properties: _} = activity
      ) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_actor, %P.Actor{values: [_ | _]} = actor} <-
           {:activity_actor, Utils.get_actor(activity)},
         # Obtain all actor IRIs.
         {:ok, actor_ids} <-
           APUtils.make_id_map(actor),
         # Obtain each object's 'attributedTo' IRIs.
         {:ok, att_to_ids} <-
           APUtils.make_id_map(object, "attributedTo") do
      # Put all missing actor IRIs onto all object attributedTo properties.
      {new_att_to_iters, att_to_ids} =
        Enum.reduce(actor_ids, {[], att_to_ids}, fn {k, v}, {acc, m} ->
          if !Map.has_key?(m, k) do
            # append_iri
            {[%P.AttributedToIterator{alias: alias_, iri: v} | acc], Map.put(m, k, v)}
          else
            {acc, m}
          end
        end)

      object = Utils.append_iters(object, "attributedTo", Enum.reverse(new_att_to_iters))
      activity = struct(activity, properties: Map.put(activity.properties, "object", object))

      # Put all missing object attributedTo IRIs onto the actor property
      new_att_to_iters =
        Enum.reduce(att_to_ids, [], fn {k, v}, acc ->
          if !Map.has_key?(actor_ids, k) do
            [%P.AttributedToIterator{alias: alias_, iri: v} | acc]
          else
            acc
          end
        end)

      actor = Utils.append_iters(actor, "attributedTo", Enum.reverse(new_att_to_iters))
      activity = struct(activity, properties: Map.put(activity.properties, "actor", actor))

      # Copy over the 'to', 'bto', 'cc', 'bcc', and 'audience' recipients
      # between the activity and all child objects and vice versa.
      case APUtils.normalize_recipients(activity) do
        {:ok, activity} ->
          # Persist all objects we've created, which will include sensitive
          # recipients such as 'bcc' and 'bto'.
          context = Map.put(context, :deliverable, true)

          Enum.reduce_while(object.values, :ok, fn
            %{member: %{__struct__: _, properties: _} = as_type}, acc ->
              case APUtils.get_id(as_type) do
                %URI{} = _id ->
                  case ActorFacade.db_create(context, as_type) do
                    {:ok, _created, _raw_json} ->
                      {:cont, acc}

                    {:error, reason} ->
                      Logger.error("Failed to persist #{inspect(as_type)}: #{reason}")
                      {:halt, {:error, reason}}
                  end

                _ ->
                  Logger.error("No id in #{inspect(as_type)}")
                  {:halt, {:error, Utils.err_id_required(activity: activity)}}
              end

            _, _ ->
              {:halt, {:error, "Object property is not a type"}}
          end)
          |> case do
            {:error, reason} -> {:error, reason}
            _ -> ActorFacade.handle_c2s_activity(context, activity)
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_actor, _} -> Utils.err_actor_required(activity: activity)
    end
  end

  @doc """
  Implements the social Update activity side effects.
  """
  @impl true
  def update(%{raw_activity: raw_activity} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)} do
      # Obtain all object ids, which should be owned by this server.
      Enum.reduce_while(values, :ok, fn
        %{member: object_type} = object_iter, acc when is_struct(object_type) ->
          case APUtils.get_id(object_iter) do
            %URI{} = id ->
              with {:ok, as_type} <- ActorFacade.db_get(context, id),
                   {:ok, m} <- Fedi.Streams.Serializer.serialize(as_type),
                   {:ok, new_m} <- Fedi.Streams.Serializer.serialize(object_type),
                   m <- Map.merge(m, new_m),
                   # Delete top-level values where the raw Activity had nils.
                   m <-
                     Enum.reduce(raw_activity, m, fn {k, _v}, acc ->
                       if Map.has_key?(acc, k) && is_nil(Map.get(acc, k)) do
                         Map.delete(acc, k)
                       else
                         acc
                       end
                     end),
                   {:ok, new_type} <- Fedi.Streams.JSONResolver.resolve(m),
                   {:ok, _updated} <- ActorFacade.db_update(context, new_type) do
                {:cont, acc}
              else
                {:error, reason} -> {:halt, {:error, reason}}
              end

            _ ->
              {:halt, {:error, Utils.err_id_required(value: object_type)}}
          end

        _non_type_iter, _acc ->
          {:halt, {:error, "Object is not a literal type value"}}
      end)
      |> case do
        {:error, reason} ->
          {:error, reason}

        _ ->
          ActorFacade.handle_c2s_activity(context, activity)
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  @doc """
  Implements the social Delete activity side effects.

  Ref: [AP Section 6.4](https://www.w3.org/TR/activitypub/#delete-activity-outbox)
  As a side effect, the server MAY replace the object with
  a Tombstone of the object that will be displayed in activities which
  reference the deleted object.
  """
  @impl true
  def delete(context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)} do
      # Obtain all object ids, which should be owned by this server.
      Enum.reduce_while(values, :ok, fn
        %{member: object_type} = object_iter, acc when is_struct(object_type) ->
          case APUtils.get_id(object_iter) do
            %URI{} = id ->
              with {:ok, as_type} <- ActorFacade.db_get(context, id),
                   tomb <- APUtils.to_tombstone(as_type, id),
                   {:ok, _updated} <- ActorFacade.db_update(context, tomb) do
                {:cont, acc}
              else
                {:error, reason} -> {:halt, {:error, reason}}
              end

            _ ->
              {:halt, {:error, Utils.err_id_required(value: object_type)}}
          end

        _non_type_iter, _acc ->
          {:halt, {:error, "Object is not a literal type value"}}
      end)
      |> case do
        {:error, reason} ->
          {:error, reason}

        _ ->
          ActorFacade.handle_c2s_activity(context, activity)
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  @doc """
  Implements the social Follow activity side effects.
  """
  @impl true
  def follow(%{box_iri: box_iri} = context, activity)
      when is_struct(context) and is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, following_ids} <- APUtils.get_ids(object),
         {:ok, %URI{path: actor_path} = actor_iri} <-
           ActorFacade.db_actor_for_outbox(context, box_iri),
         coll_id <- %URI{actor_iri | path: actor_path <> "/following"},
         ActorFacade.db_update_collection(context, coll_id, %{add: following_ids}) do
      ActorFacade.handle_c2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  @doc """
  Implements the social Add activity side effects.

  Ref: [AP Section 6.1](https://w3.org/TR/activitypub/#client-addressing)
  Additionally, clients submitting the following activities to an outbox
  MUST also provide the target property: Add, Remove.
  """
  @impl true
  def add(context, activity)
      when is_struct(context) and is_struct(activity) do
    with {:activity_object, object} when is_struct(object) <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_target, target} when is_struct(target) <-
           {:activity_target, Utils.get_target(activity)},
         :ok <- APUtils.add(context, object, target) do
      ActorFacade.handle_c2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> {:error, Utils.err_object_required(activity: activity)}
      {:activity_target, _} -> {:error, Utils.err_target_required(activity: activity)}
    end
  end

  @doc """
  Implements the social Remove activity side effects.
  """
  @impl true
  def remove(context, activity)
      when is_struct(context) and is_struct(activity) do
    with {:activity_object, object} when is_struct(object) <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_target, target} when is_struct(target) <-
           {:activity_target, Utils.get_target(activity)},
         :ok <- APUtils.remove(context, object, target) do
      ActorFacade.handle_c2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> {:error, Utils.err_object_required(activity: activity)}
      {:activity_target, _} -> {:error, Utils.err_target_required(activity: activity)}
    end
  end

  @doc """
  Implements the social Like activity side effects.
  """
  @impl true
  def like(%{box_iri: outbox_iri} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, %URI{path: actor_path} = actor_iri} <-
           ActorFacade.db_actor_for_outbox(context, outbox_iri),
         {:ok, object_ids} <- APUtils.get_ids(object),
         {:ok, recipients} <- APUtils.get_recipients(activity),
         items <- Enum.map(object_ids, fn id -> {id, recipients} end),
         coll_id <- %URI{actor_iri | path: actor_path <> "/liked"},
         {:ok, _oc} <- ActorFacade.db_update_collection(context, coll_id, %{add: items}) do
      ActorFacade.handle_c2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  @doc """
  Implements the social Undo activity side effects.
  """
  @impl true
  def undo(context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]}} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_actor, %P.Actor{values: [_ | _]} = actor} <-
           {:activity_actor, Utils.get_actor(activity)},
         :ok <- APUtils.object_actors_match_activity_actors?(context, actor) do
      context = Map.put(context, :deliverable, true)
      ActorFacade.handle_c2s_activity(context, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_actor, _} -> Utils.err_actor_required(activity: activity)
    end
  end

  @doc """
  Implements the social Block activity side effects.
  """
  @impl true
  def block(context, activity) when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]}} <-
           {:activity_object, Utils.get_object(activity)} do
      # Mark the activity as non-deliverable
      ActorFacade.handle_c2s_activity(struct(context, deliverable: false), activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end
end
