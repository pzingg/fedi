defmodule Fedi.ActivityPub.SocialActivityHandler do
  @moduledoc """
  Callback functions that already have some side effect behavior.
  """

  @behaviour Fedi.ActivityPub.SocialActivityApi

  require Logger

  alias Fedi.ActivityPub.Actor
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T

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
  def create(
        %{database: database, data: context_data} = context,
        %{alias: alias_, properties: _} = activity
      )
      when is_atom(database) do
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

      actor = Utils.append_iters(context, "attributedTo", Enum.reverse(new_att_to_iters))
      activity = struct(activity, properties: Map.put(activity.properties, "actor", actor))

      # Copy over the 'to', 'bto', 'cc', 'bcc', and 'audience' recipients
      # between the activity and all child objects and vice versa.
      case APUtils.normalize_recipients(activity) do
        {:ok, activity} ->
          # Persist all objects we've created, which will include sensitive
          # recipients such as 'bcc' and 'bto'.
          context_data = Map.put(context_data, :undeliverable, false)
          context = Map.put(context, :data, context_data)

          Enum.reduce_while(object.values, :ok, fn
            %{member: %{__struct__: _, properties: _} = as_type}, acc ->
              case APUtils.get_id(as_type) do
                %URI{} = _id ->
                  case apply(database, :create, [as_type]) do
                    {:ok, _} ->
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
            _ -> Actor.handle_activity(context, :c2s, activity)
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
  def update(%{database: database, data: %{raw_activity: raw_activity}} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)} do
      # Obtain all object ids, which should be owned by this server.
      Enum.reduce_while(values, :ok, fn
        %{member: object_type} = object_iter, acc when is_struct(object_type) ->
          case APUtils.get_id(object_iter) do
            %URI{} = id ->
              with {:ok, as_type} <- apply(database, :get, [id]),
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
                   {:ok, _updated, _raw_json} <- apply(database, :update, [new_type]) do
                {:cont, acc}
              else
                {:error, reason} -> {:halt, {:error, reason}}
              end

            _ ->
              {:halt, {:error, Utils.err_id_required(object: object_type)}}
          end

        _non_type_iter, _acc ->
          {:halt, {:error, "Object is not a literal type value"}}
      end)
      |> case do
        {:error, reason} ->
          {:error, reason}

        _ ->
          Actor.handle_activity(context, :c2s, activity)
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
  def delete(%{database: database} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _] = values}} <-
           {:activity_object, Utils.get_object(activity)} do
      # Obtain all object ids, which should be owned by this server.
      Enum.reduce_while(values, :ok, fn
        %{member: object_type} = object_iter, acc when is_struct(object_type) ->
          case APUtils.get_id(object_iter) do
            %URI{} = id ->
              with {:ok, as_type} <- apply(database, :get, [id]),
                   tomb <- APUtils.to_tombstone(as_type, id),
                   {:ok, _updated, _raw_json} <- apply(database, :update, [tomb]) do
                {:cont, acc}
              else
                {:error, reason} -> {:halt, {:error, reason}}
              end

            _ ->
              {:halt, {:error, Utils.err_id_required(object: object_type)}}
          end

        _non_type_iter, _acc ->
          {:halt, {:error, "Object is not a literal type value"}}
      end)
      |> case do
        {:error, reason} ->
          {:error, reason}

        _ ->
          Actor.handle_activity(context, :c2s, activity)
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  @doc """
  Implements the social Follow activity side effects.
  """
  def follow(context, activity)
      when is_struct(context) and is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]}} <-
           {:activity_object, Utils.get_object(activity)} do
      Actor.handle_activity(context, :c2s, activity)
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
  def add(context, activity)
      when is_struct(context) and is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_target, %P.Target{values: [_ | _]} = target} <-
           {:activity_target, Utils.get_target(activity)},
         :ok <- APUtils.add(context, object, target) do
      Actor.handle_activity(context, :c2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_target, _} -> Utils.err_target_required(activity: activity)
    end
  end

  @doc """
  Implements the social Remove activity side effects.
  """
  def remove(context, activity)
      when is_struct(context) and is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_target, %P.Target{values: [_ | _]} = target} <-
           {:activity_target, Utils.get_target(activity)},
         :ok <- APUtils.remove(context, object, target) do
      Actor.handle_activity(context, :c2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_target, _} -> Utils.err_target_required(activity: activity)
    end
  end

  @doc """
  Implements the social Like activity side effects.
  """
  def like(%{database: database, data: %{box_iri: outbox_iri}} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]} = object} <-
           {:activity_object, Utils.get_object(activity)},
         {:ok, actor_iri} <- apply(database, :actor_for_outbox, outbox_iri),
         {:ok, liked} <- apply(database, :liked, actor_iri),
         {:ok, object_ids} <- APUtils.get_ids(object),
         liked <- Utils.prepend_iris(liked, "items", object_ids),
         {:ok, _updated, _raw_json} <- apply(database, :update, [liked]) do
      Actor.handle_activity(context, :c2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end

  @doc """
  Implements the social Undo activity side effects.
  """
  def undo(%{data: context_data} = context, activity)
      when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]}} <-
           {:activity_object, Utils.get_object(activity)},
         {:activity_actor, %P.Actor{values: [_ | _]} = actor} <-
           {:activity_actor, Utils.get_actor(activity)},
         :ok <- APUtils.object_actors_match_activity_actors?(context, actor) do
      context_data = Map.put(context_data, :undeliverable, false)
      context = Map.put(context, :data, context_data)
      Actor.handle_activity(context, :c2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
      {:activity_actor, _} -> Utils.err_actor_required(activity: activity)
    end
  end

  @doc """
  Implements the social Block activity side effects.
  """
  def block(%{data: context_data} = context, activity) when is_struct(activity) do
    with {:activity_object, %P.Object{values: [_ | _]}} <-
           {:activity_object, Utils.get_object(activity)} do
      context_data = Map.put(context_data, :undeliverable, true)
      context = Map.put(context, :data, context_data)
      Actor.handle_activity(context, :c2s, activity)
    else
      {:error, reason} -> {:error, reason}
      {:activity_object, _} -> Utils.err_object_required(activity: activity)
    end
  end
end
