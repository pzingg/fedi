defmodule FediServerWeb.SocialCallbacks do
  @moduledoc """
  Provides all the Social API logic for our example.
  """

  @behaviour Fedi.ActivityPub.CommonApi
  @behaviour Fedi.ActivityPub.SocialApi
  @behaviour Fedi.ActivityPub.SocialActivityApi

  require Logger

  alias Fedi.Streams.Error
  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.ActorFacade
  alias Fedi.ActivityPub.SideEffectActor
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities
  alias FediServer.Accounts.User
  alias FediServerWeb.CommonCallbacks

  @impl true
  defdelegate authenticate_get_inbox(context, conn), to: CommonCallbacks

  @impl true
  defdelegate get_inbox(context, conn, params), to: CommonCallbacks

  @impl true
  defdelegate authenticate_get_outbox(context, conn), to: CommonCallbacks

  @impl true
  defdelegate get_outbox(context, conn, params), to: CommonCallbacks

  @impl true
  defdelegate post_outbox(context, activity, outbox_iri, raw_json), to: CommonCallbacks

  @doc """
  Hook callback after parsing the request body for a client request
  to the Actor's outbox.

  Only called if the Social API is enabled.

  Can be used to set contextual information or to prevent further processing
  based on the Activity received, such as when the current user
  is not authorized to post the activity.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_outbox/3`. In this case, the implementation must not
  send a response to the connection as it is expected that the caller
  to `Actor.handle_post_outbox/3` will do so when handling the error.
  """
  @impl true
  def post_outbox_request_body_hook(context, %Plug.Conn{} = _conn, activity) do
    with {:ok, context} <- verify_actor_and_attributed_to(context, activity) do
      check_object_spoofing(context, activity)
    end
  end

  def verify_actor_and_attributed_to(
        %{current_user: %{ap_id: current_user_id}} = context,
        activity
      ) do
    case Utils.get_iri(activity, "actor") do
      %URI{} = id ->
        actor_id = URI.to_string(id)

        if actor_id != current_user_id do
          {:error,
           %Error{
             code: :unauthorized_create,
             status: :unauthorized,
             message: "Current user can not create activity for actor #{actor_id}"
           }}
        else
          {:ok, context}
        end

      _ ->
        # No 'actor'. Verify 'attributedTo'
        with true <- APUtils.is_or_extends?(activity, "Create"),
             object when is_struct(object) <- Utils.get_object(activity),
             %URI{} = id <- Utils.get_iri(object, "attributedTo"),
             attributed_to_id <- URI.to_string(id),
             false <- attributed_to_id == current_user_id do
          {:error,
           %Error{
             code: :unauthorized_create,
             status: :unauthorized,
             message: "Current user can not create object attributed to #{attributed_to_id}"
           }}
        else
          _ ->
            {:ok, context}
        end
    end
  end

  # Ref: AP Section 3. Preventing spoofing attacks. When an activity has an
  # object id, the server should dereference the id
  # both to ensure that it exists and is a valid object, and that it is not
  # misrepresenting the object.
  def check_object_spoofing(context, activity) do
    if APUtils.is_or_extends?(activity, ["Update", "Like", "Announce"]) do
      case APUtils.get_object_id(activity) do
        {:ok, object_id} ->
          with {:original_object, {:ok, derefed_m}} <-
                 {:original_object, ActorFacade.db_dereference(context, object_id)},
               {:ok, activity_m} <- Fedi.Streams.Serializer.serialize(activity) do
            case activity_m["object"] do
              object_m when is_map(object_m) ->
                case unmatched_property?(["type", "attributedTo"], object_m, derefed_m) do
                  prop_name when is_binary(prop_name) ->
                    Logger.error(
                      "Object spoofed at #{prop_name}:\n   db has #{inspect(derefed_m[prop_name])}\n  act has #{inspect(object_m[prop_name])}"
                    )

                    {:error,
                     %Error{
                       code: :object_spoofed,
                       status: :unprocessable_entity,
                       message: "Object's '#{prop_name}' value may be spoofed"
                     }}

                  _ ->
                    {:ok, context}
                end

              _object_id_or_nil ->
                {:ok, context}
            end
          else
            {:error, reason} ->
              {:error, reason}

            {:original_object, _} ->
              Logger.error("No existing object at #{object_id}")

              {:error,
               %Error{
                 code: :object_spoofed,
                 status: :unprocessable_entity,
                 message: "Object #{object_id} does not exist"
               }}
          end

        _ ->
          {:ok, context}
      end
    else
      {:ok, context}
    end
  end

  def unmatched_property?(prop_names, object_m, derefed_m) do
    List.wrap(prop_names)
    |> Enum.find(fn prop_name ->
      if object_m[prop_name] == derefed_m[prop_name] do
        nil
      else
        prop_name
      end
    end)
  end

  @doc """
  Sets new ids on the activity. It also does so for all
  'object' properties if the Activity is a Create type.

  Only called if the Social API is enabled.

  If an error is returned, it is returned to the caller of
  `Actor.handle_post_outbox/3`.
  """
  @impl true
  defdelegate add_new_ids(context, activity), to: SideEffectActor

  @doc """
  Delegates the authentication and authorization of a POST to an outbox.

  Only called if the Social API is enabled.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_outbox/3`. In this case, the implementation must not send a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles sending a response to the connection in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  @impl true
  def authenticate_post_outbox(
        %{current_user: current_user} = context,
        %Plug.Conn{} = conn
      ) do
    case current_user do
      %{ap_id: _current_user_id} ->
        {:ok, context, conn, true}

      _ ->
        Logger.error("No current user")
        {:ok, context, conn, false}
    end
  end

  @doc """
  Wraps the provided object in a Create ActivityStreams
  activity. `outbox_iri` is the actor's outbox endpoint.

  Only called if the Social API is enabled.
  """
  @impl true
  defdelegate wrap_in_create(context, value, outbox_iri), to: SideEffectActor

  @doc """
  A no-op for the Social API.
  """
  @impl true
  def default_callback(_context, _activity) do
    :pass
  end

  ### Activity handlers

  @doc """
  Create a following relationship.
  """
  @impl true
  def follow(_context, activity) do
    Logger.debug("Follow")

    with {:activity_actor, actor} <- {:activity_actor, Utils.get_actor(activity)},
         {:activity_object, object} <- {:activity_object, Utils.get_object(activity)},
         {:actor_id, %URI{} = actor_iri} <- {:actor_id, APUtils.to_id(actor)},
         {:following_id, %URI{} = following_id} <- {:following_id, APUtils.to_id(object)},
         {:ok, %User{}} <- Activities.ensure_user(actor_iri, true),
         # Insert remote following user if not in db
         {:ok, %User{}} <- Activities.ensure_user(following_id, false),
         {:ok, _relationship} <- Activities.follow(actor_iri, following_id, :pending) do
      {:ok, activity, true}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Insert error #{Activities.describe_errors(changeset)}")
        {:error, "Internal database error"}

      {:error, reason} ->
        Logger.error("Follow error #{reason}")
        {:error, reason}

      {:activity_actor, _} ->
        {:error, Utils.err_actor_required(activity: activity)}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: activity)}

      {:actor_id, _} ->
        {:error, "No id in actor"}

      {:following_id, _} ->
        {:error, "No following id in object"}
    end
  end

  @impl true
  def block(_context, activity) when is_struct(activity) do
    with {:activity_actor, actor} <- {:activity_actor, Utils.get_actor(activity)},
         {:activity_object, object} <- {:activity_object, Utils.get_object(activity)},
         {:actor_id, %URI{} = actor_iri} <- {:actor_id, APUtils.to_id(actor)},
         {:blocked_id, %URI{} = blocked_id} <- {:blocked_id, APUtils.to_id(object)},
         {:ok, %User{} = user} <- Activities.ensure_user(actor_iri, true),
         {:ok, _blocked_account} <- Activities.block(user, blocked_id) do
      Logger.error("Blocked #{blocked_id}")
      {:ok, activity, false}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Insert error #{Activities.describe_errors(changeset)}")
        {:error, "Internal database error"}

      {:error, reason} ->
        Logger.error("Block error #{reason}")
        {:error, reason}

      {:activity_actor, _} ->
        {:error, Utils.err_actor_required(activity: activity)}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: activity)}

      {:actor_id, _} ->
        {:error, "No id in actor"}

      {:blocked_id, _} ->
        {:error, "No id in object"}
    end
  end

  @doc """
  Undo for the Social API. We'll support what Mastodon does:

  * Undo/Accept
  * Undo/Follow
  * Undo/Block
  * Undo/Like
  * Undo/Announce
  """
  @impl true
  def undo(context, activity) when is_struct(activity) do
    with {:activity_object, object} <-
           {:activity_object, Utils.get_object_type(activity)},
         {:activity_actor, %URI{} = actor_iri} <-
           {:activity_actor, Utils.get_iri(activity, "actor")} do
      case Utils.get_json_ld_type(object) do
        "Accept" ->
          case undo_accept(context, actor_iri, object) do
            :ok -> {:ok, activity, true}
            {:error, reason} -> {:error, reason}
          end

        "Follow" ->
          case undo_follow(context, actor_iri, object) do
            :ok -> {:ok, activity, true}
            {:error, reason} -> {:error, reason}
          end

        "Block" ->
          case undo_block(context, actor_iri, object) do
            :ok -> {:ok, activity, false}
            {:error, reason} -> {:error, reason}
          end

        "Like" ->
          case undo_like(context, actor_iri, object) do
            :ok -> {:ok, activity, true}
            {:error, reason} -> {:error, reason}
          end

        "Announce" ->
          case undo_announce(context, actor_iri, object) do
            :ok -> {:ok, activity, true}
            {:error, reason} -> {:error, reason}
          end

        other ->
          {:error,
           %Error{
             code: :undo_type_not_supported,
             status: :unprocessable_entity,
             message: "Undo #{other} is not supported"
           }}
      end
    else
      {:activity_actor, _} ->
        {:error, Utils.err_actor_required(activity: activity)}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: activity)}
    end
  end

  def undo_accept(context, _actor_iri, accept) do
    with {:ok, %URI{path: actor_path} = actor_iri, accept_actors} <-
           APUtils.validate_accept_or_reject(context, accept),
         coll_id <-
           %URI{actor_iri | path: actor_path <> "/following"},
         {:ok, _} <-
           ActorFacade.db_update_collection(context, coll_id, %{
             delete: accept_actors
           }) do
      :ok
    end
  end

  def undo_follow(_context, actor_iri, follow) do
    with {:activity_object, object} <-
           {:activity_object, Utils.get_object(follow)},
         {:following_id, %URI{} = following_id} <-
           {:following_id, APUtils.to_id(object)},
         {:ok, %User{}} <-
           Activities.ensure_user(actor_iri, true) do
      Activities.unfollow(actor_iri, following_id)
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: follow)}

      {:following_id, _} ->
        {:error, "No following id in object"}
    end
  end

  def undo_block(_context, actor_iri, block) do
    with {:activity_object, object} <-
           {:activity_object, Utils.get_object(block)},
         {:blocked_id, %URI{} = blocked_id} <-
           {:blocked_id, APUtils.to_id(object)},
         {:ok, %User{} = user} <-
           Activities.ensure_user(actor_iri, true) do
      Activities.unblock(user, blocked_id)
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: block)}

      {:blocked_id, _} ->
        {:error, "No id in object"}
    end
  end

  def undo_like(context, %URI{path: actor_path} = actor_iri, like) do
    with {:activity_object, object} <-
           {:activity_object, Utils.get_object(like)},
         {:ok, object_ids} <-
           APUtils.get_ids(object),
         coll_id <-
           %URI{actor_iri | path: actor_path <> "/collections/liked"},
         {:ok, _oc} <-
           ActorFacade.db_update_collection(context, coll_id, %{remove: object_ids}) do
      :ok
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: like)}
    end
  end

  def undo_announce(context, actor_iri, announce) do
    with {:activity_object, object} <-
           {:activity_object, Utils.get_object(announce)},
         {:ok, object_ids} <-
           APUtils.get_ids(object),
         {:ok, _oc} <-
           APUtils.update_object_collections(
             context,
             actor_iri,
             nil,
             object_ids,
             "shares",
             :remove
           ) do
      :ok
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_object, _} ->
        {:error, Utils.err_object_required(activity: announce)}
    end
  end
end
