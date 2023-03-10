defmodule Fedi.ActivityPub.ActorBehavior do
  @moduledoc """
  ActorBehavior contains the detailed interface an application must satisfy in
  order to implement the ActivityPub specification.

  Note that an implementation of this interface is implicitly provided in the
  calls to `SideEffectActor.new/2`.

  Implementing the ActorBehavior requires familiarity with the ActivityPub
  specification because it does not a strong enough abstraction for the client
  application to ignore the ActivityPub spec. It is very possible to implement
  this interface and build a foot-gun that trashes the fediverse without being
  ActivityPub compliant. Please use with due consideration.

  Alternatively, build an application that uses the parts of the library
  that do not require implementing a ActorBehavior so that the ActivityPub
  implementation is completely provided out of the box.
  """

  alias Fedi.ActivityPub.ActorFacade

  @type context() :: ActorFacade.context()

  @doc """
  Hook callback after parsing the request body for a federated request
  to the Actor's inbox.

  Only called if the Federated Protocol is enabled.

  Can be used to set contextual information or to prevent further processing
  based on the Activity received.

  Authentication has been approved, but authorization has not been
  checked when this hook is called.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_inbox/3`. In this case, the implementation must not
  send a response to the connection as is expected that the caller
  to `Actor.handle_post_inbox/3` will do so when handling the error.
  """
  @callback post_inbox_request_body_hook(
              context :: context(),
              conn :: Plug.Conn.t(),
              activity :: struct()
            ) ::
              {:ok, context :: context()} | {:error, term()}

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
  @callback post_outbox_request_body_hook(context :: context(), activity :: struct()) ::
              {:ok, context :: context()} | {:error, term()}

  @doc """
  Delegates the authentication of a POST to an inbox.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_inbox/3`. In this case, the implementation must not send a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false. It is expected that
  the implementation handles sending a response in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true. The request will continue
  to be processed.
  """
  @callback authenticate_post_inbox(
              context :: context(),
              conn :: Plug.Conn.t()
            ) ::
              {:ok, context :: context(), conn :: Plug.Conn.t(), authenticated :: boolean()}
              | {:error, term()}

  @doc """
  Delegates the authentication of a GET to an inbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_get_inbox/3`. In this case, the implementation must not send a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false. It is expected that
  the implementation handles sending to the connection in this case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true. The request will continue
  to be processed.
  """
  @callback authenticate_get_inbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, context :: context(), conn :: Plug.Conn.t(), authenticated :: boolean()}
              | {:error, term()}

  @doc """
  Delegates the authorization of an activity that
  has been sent by POST to an inbox.

  Only called if the Federated Protocol is enabled.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_inbox/3`. In this case, the implementation must not send a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authorized' is ignored.

  If no error is returned, but authorization fails, then authorized
  must be false and error nil. It is expected that the implementation
  handles sending to the connection in this case.

  Finally, if the authorization succeeds, then
  authorized must be true and error nil. The request will continue
  to be processed.
  """
  @callback authorize_post_inbox(
              context :: context(),
              conn :: Plug.Conn.t(),
              activity :: struct()
            ) ::
              {:ok, Plug.Conn.t(), authorized :: boolean()} | {:error, term()}

  @doc """
  Delegates the authentication and authorization of a POST to an outbox.

  Only called if the Social API is enabled.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_outbox/3`. In this case, the implementation must not send a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false. It is expected that
  the implementation handles sending to the connection in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true. The request will continue
  to be processed.
  """
  @callback authenticate_post_outbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, context :: context(), conn :: Plug.Conn.t(), authenticated :: boolean()}
              | {:error, term()}

  @doc """
  Delegates the authentication of a GET to an outbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_get_outbox/3`. In this case, the implementation must not send a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false. It is expected that
  the implementation handles sending to the connection in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true. The request will continue
  to be processed.
  """
  @callback authenticate_get_outbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, context :: context(), conn :: Plug.Conn.t(), authenticated :: boolean()}
              | {:error, term()}

  @doc """
  Delegates the side effects of adding to the inbox and
  determining if it is a request that should be blocked.

  Only called if the Federated Protocol is enabled.

  As a side effect, sets the federated data in the inbox, but
  not on its own in the database, as `inbox_forwarding` (which is called
  later) must decide whether it has seen this activity before in order
  to determine whether to do the forwarding algorithm.

  If the error is `:object_required` or `:target_required`, then a Bad
  Request status is sent in the response.
  """
  @callback post_inbox(context :: context(), inbox_iri :: URI.t(), activity :: struct()) ::
              {:ok, context :: context()} | {:error, term()}

  @doc """
  Delegates inbox forwarding logic when a POST request
  is received in the Actor's inbox.

  Only called if the Federated Protocol is enabled.

  The delegate is responsible for determining whether to do the inbox
  forwarding, as well as actually conducting it if it determines it
  needs to.

  As a side effect, `inbox_forwarding/3` must set the federated data in the
  database, independently of the inbox, however it sees fit in order to
  determine whether it has seen the activity before.

  The provided URI is the inbox of the recipient of the Activity. The
  Activity is examined for the information about who to inbox forward
  to.

  If an error is returned, it is returned to the caller of
  `Actor.handle_post_inbox/3`.
  """
  @callback inbox_forwarding(context :: context(), inbox_iri :: URI.t(), activity :: term()) ::
              :ok | {:error, term()}

  @doc """
  Delegates the logic for side effects and adding to the
  outbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled. In the case of the Social API being enabled, side
  effects of the Activity must occur.

  The delegate is responsible for adding the activity to the database's
  general storage for independent retrieval, and not just within the
  actor's outbox.

  If the error is `:object_required` or `:target_required`, then a Bad
  Request status is sent in the response.

  Note that `raw_json` is an unfortunate consequence where an Update
  Activity is the only one that explicitly cares about null values in
  JSON. Since the library does not differentiate between null values and
  values that are simply not present, the `raw_json` map is ONLY needed
  for this narrow and specific use case.
  """
  @callback post_outbox(
              context :: context(),
              activity :: term(),
              outbox_iri :: URI.t(),
              raw_json :: map()
            ) ::
              {:ok, deliverable :: boolean()} | {:error, term()}

  @doc """
  Sets new URL ids on the activity. It also does so for all
  'object' properties if the Activity is a Create type.

  Only called if the Social API is enabled.

  If an error is returned, it is returned to the caller of
  `Actor.handle_post_outbox/3`.
  """
  @callback add_new_ids(context :: context(), activity :: term(), drop_existing_ids? :: boolean()) ::
              {:ok, activity :: term()} | {:error, term()}

  @doc """
  Sends a federated message. Called only if federation is
  enabled.

  Called if the Federated Protocol is enabled.

  `outbox_iri` is the outbox of the sender. The Activity contains
  the information about the intended recipients.

  If an error is returned, it is returned to the caller of
  `Actor.handle_post_outbox/3`.
  """
  @callback deliver(context :: context(), outbox_iri :: URI.t(), activity :: term()) ::
              {:ok, queued :: non_neg_integer()} | {:error, term()}

  @doc """
  Wraps the provided object in a Create ActivityStreams
  activity. `outbox_iri` is the actor's outbox endpoint.

  Only called if the Social API is enabled.
  """
  @callback wrap_in_create(context :: context(), value :: term(), outbox_iri :: URI.t()) ::
              {:ok, create :: term()} | {:error, term()}
end
