defmodule Fedi.ActivityPub.SideEffectActor do
  @moduledoc """
  SideEffectActor handles the ActivityPub
  implementation side effects, but requires a more opinionated application to
  be written.

  Note that when using the sideEffectActor with an application that good-faith
  implements its required interfaces, the ActivityPub specification is
  guaranteed to be correctly followed.
  """

  @behaviour Fedi.ActivityPub.ActorBehavior

  alias Fedi.ActivityPub.Actor

  @enforce_keys [:common]
  defstruct [
    :common,
    :c2s,
    :s2s,
    :fallback,
    :database,
    :enable_social_protocol,
    :enable_federated_protocol,
    :data
  ]

  @type t() :: %__MODULE__{
          common: module(),
          c2s: module() | nil,
          s2s: module() | nil,
          fallback: module() | nil,
          database: module() | nil,
          enable_social_protocol: boolean(),
          enable_federated_protocol: boolean(),
          data: term()
        }

  def new(common, opts \\ []) do
    Fedi.ActivityPub.Actor.make_actor(__MODULE__, common, opts)
  end

  @doc """
  Defers to the federating protocol whether the peer request
  is authorized based on the actors' ids.
  """
  def authorize_post_inbox(%{s2s: _} = actor, %Plug.Conn{} = conn, activity) do
    case Fedi.Streams.Utils.get_actors(activity) do
      values when is_list(values) ->
        result =
          values
          |> Enum.with_index()
          |> Enum.reduce_while([], fn {value, idx}, acc ->
            case Fedi.Streams.Utils.get_iri_or_id(value) do
              %URI{} = actor_id ->
                {:cont, [actor_id | acc]}

              _ ->
                {:halt, {:error, "Actor at index #{idx + 1} is missing an id"}}
            end
          end)

        case result do
          {:error, reason} ->
            {:error, reason}

          actor_ids ->
            # Determine if the actor(s) sending this request are blocked.
            case Actor.delegate(actor, :s2s, :blocked, [actor_ids]) do
              {:ok, unauthorized} ->
                {:ok, {conn, !unauthorized}}

              {:error, :callback_not_found} ->
                {:ok, {conn, true}}

              {:error, reason} ->
                {:error, reason}
            end
        end

      _ ->
        {:error, "No actors in post to inbox"}
    end
  end

  @doc """
  post_inbox delegates the side effects of adding to the inbox and
  determining if it is a request that should be blocked.

  Only called if the Federated Protocol is enabled.

  As a side effect, post_inbox sets the federated data in the inbox, but
  not on its own in the database, as inbox_forwarding (which is called
  later) must decide whether it has seen this activity before in order
  to determine whether to do the forwarding algorithm.

  If the error is ErrObjectRequired or ErrTargetRequired, then a Bad
  Request status is sent in the response.
  """
  def post_inbox(actor, %URI{} = inbox_iri, activity) do
    case add_to_inbox_if_new(actor, inbox_iri, activity) do
      {:error, reason} ->
        {:error, reason}

      {:ok, false} ->
        :ok

      {:ok, true} ->
        # Wrapped data for callbacks
        actor = %{actor | data: %{inbox_iri: inbox_iri}}

        # TODO callback resolvers
        case Actor.delegate(actor, :s2s, :new_type_resolver, [inbox_iri, activity, nil]) do
          {:error, :callback_not_found} ->
            case Actor.delegate(actor, :s2s, :default_callback, [activity]) do
              {:error, reason} -> {:error, reason}
              _ -> :ok
            end

          {:error, reason} ->
            {:error, reason}

          _ ->
            :ok
        end
    end
  end

  @doc """
  inbox_forwarding delegates inbox forwarding logic when a POST request
  is received in the Actor's inbox.

  Only called if the Federated Protocol is enabled.

  The delegate is responsible for determining whether to do the inbox
  forwarding, as well as actually conducting it if it determines it
  needs to.

  As a side effect, inbox_forwarding must set the federated data in the
  database, independently of the inbox, however it sees fit in order to
  determine whether it has seen the activity before.

  The provided url is the inbox of the recipient of the Activity. The
  Activity is examined for the information about who to inbox forward
  to.

  If an error is returned, it is returned to the caller of post_inbox.
  """
  def inbox_forwarding(actor, %URI{} = inbox_iri, activity) do
    {:error, "Unimplemented"}
  end

  @doc """
  post_outbox delegates the logic for side effects and adding to the
  outbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled. In the case of the Social API being enabled, side
  effects of the Activity must occur.

  The delegate is responsible for adding the activity to the database's
  general storage for independent retrieval, and not just within the
  actor's outbox.

  If the error is ErrObjectRequired or ErrTargetRequired, then a Bad
  Request status is sent in the response.

  Note that 'raw_json' is an unfortunate consequence where an 'Update'
  Activity is the only one that explicitly cares about 'null' values in
  JSON. Since go-fed does not differentiate between 'null' values and
  values that are simply not present, the 'raw_json' map is ONLY needed
  for this narrow and specific use case.
  """
  def post_outbox(actor, %URI{} = outbox_iri, activity, raw_json) do
    if Actor.protocol_supported?(actor, :c2s) do
      # Wrapped data for callbacks
      actor = %{actor | data: %{outbox_iri: outbox_iri, raw_activity: raw_json}}

      case Actor.delegate(actor, :c2s, :new_type_resolver, [outbox_iri, activity, raw_json]) do
        {:error, :callback_not_found} ->
          case Actor.delegate(actor, :s2s, :default_callback, [activity]) do
            {:error, reason} -> {:error, reason}
            _ -> :ok
          end

        {:error, reason} ->
          {:error, reason}

        _ ->
          :ok
      end
    else
    end

    {:ok, true}
  end

  @doc """
  add_new_ids sets new URL ids on the activity. It also does so for all
  'object' properties if the Activity is a Create type.

  Only called if the Social API is enabled.

  If an error is returned, it is returned to the caller of post_outbox.
  """
  def add_new_ids(context, activity) do
    {:ok, activity}
  end

  @doc """
  deliver sends a federated message. Called only if federation is
  enabled.

  Called if the Federated Protocol is enabled.

  The provided url is the outbox of the sender. The Activity contains
  the information about the intended recipients.

  If an error is returned, it is returned to the caller of post_outbox.
  """
  def deliver(actor, %URI{} = outbox, activity) do
    :ok
  end

  @doc """
  Delegates the authentication and authorization
  of a POST to an outbox.

  Only called if the Social API is enabled.

  If an error is returned, it is passed back to the caller of
  post_outbox. In this case, the implementation must not write a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles writing to the connection in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  def authenticate_post_outbox(actor, %Plug.Conn{} = conn) do
    Actor.delegate(actor, :c2s, :authenticate_post_outbox, [conn])
  end

  @doc """
  Delegates the authentication of a GET to an outbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.

  If an error is returned, it is passed back to the caller of
  get_outbox. In this case, the implementation must not write a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles writing to the connection in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  def authenticate_get_outbox(actor, %Plug.Conn{} = conn) do
    Actor.delegate(actor, :common, :authenticate_get_outbox, [conn])
  end

  @doc """
  wrap_in_create wraps the provided object in a Create ActivityStreams
  activity. The provided URL is the actor's outbox endpoint.

  Only called if the Social API is enabled.
  """
  def wrap_in_create(actor, value, %URI{} = outbox_iri) do
    # {:ok, create}
    {:error, "Unimplemented"}
  end

  @doc """
  get_outbox returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  authenticate_get_outbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  def get_outbox(actor, %Plug.Conn{} = conn) do
    Actor.delegate(actor, :common, :get_outbox, [conn])
  end

  @doc """
  GetInbox returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  authenticate_get_inbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  def get_inbox(actor, %Plug.Conn{} = conn) do
    Actor.delegate(actor, :s2s, :get_inbox, [conn])
  end

  # Adds the activity to the inbox at the specified IRI if
  # the activity's ID has not yet been added to the inbox.
  #
  # It does not add the activity to this database's know federated data.
  #
  # Returns true when the activity is novel.
  defp add_to_inbox_if_new(%{database: db_context}, %URI{} = inbox_iri, activity) do
    with %URI{} = id <- Fedi.Streams.Utils.get_json_ld_id(activity),
         {:ok, false} <- apply(db_context, :inbox_contains, [inbox_iri, id]) do
      # It is a new id, acquire the inbox.
      update_inbox = fn inbox ->
        oi =
          Fedi.Streams.Utils.get_ordered_items(inbox) ||
            Fedi.Streams.Utils.new_ordered_items()

        oi = Fedi.Streams.PropertyIterator.prepend_iri(oi, id)
        Fedi.Streams.Utils.set_ordered_items(inbox, oi)
      end

      apply(db_context, :update_inbox, [inbox_iri, update_inbox])
    else
      # If the inbox already contains the URL, early exit.
      {:ok, true} -> {:ok, false}
      {:error, reason} -> {:error, reason}
      nil -> {:error, "Activity does not have an id"}
    end
  end
end
