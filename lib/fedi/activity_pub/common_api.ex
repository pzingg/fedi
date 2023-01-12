defmodule Fedi.ActivityPub.CommonApi do
  @moduledoc """
  Common contains functions required for both the Social API and Federating
  Protocol.

  It is passed to the library as a dependency injection from the client
  application.
  """

  @type context :: Fedi.ActivityPub.Actor.context()

  @doc """
  AuthenticateGetInbox delegates the authentication of a GET to an
  inbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.

  If an error is returned, it is passed back to the caller of
  GetInbox. In this case, the implementation must not write a
  response to the ResponseWriter as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles writing to the ResponseWriter in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  @callback authenticate_get_inbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, {response :: Plug.Conn.t(), authenticated :: boolean}} | {:error, term()}

  @doc """
  Returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  AuthenticateGetInbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  @callback get_inbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, {response :: Plug.Conn.t(), ordered_collection :: struct()}}
              | {:error, term()}

  @doc """
  AuthenticateGetOutbox delegates the authentication of a GET to an
  outbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.

  If an error is returned, it is passed back to the caller of
  GetOutbox. In this case, the implementation must not write a
  response to the ResponseWriter as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles writing to the ResponseWriter in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  @callback authenticate_get_outbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, {response :: Plug.Conn.t(), authenticated :: boolean}} | {:error, term()}

  @doc """
  Returns the OrderedCollection outbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  AuthenticateGetOutbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  @callback get_outbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, {response :: Plug.Conn.t(), ordered_collection :: struct()}}
              | {:error, term()}

  @doc """
  Delegates the logic for side effects and adding to the
  outbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled. In the case of the Social API being enabled, side
  effects of the Activity must occur.

  The delegate is responsible for adding the activity to the database's
  general storage for independent retrieval, and not just within the
  actor's outbox.

  If the error is ErrObjectRequired or ErrTargetRequired, then a Bad
  Request status is sent in the response.

  Note that 'rawJSON' is an unfortunate consequence where an 'Update'
  Activity is the only one that explicitly cares about 'null' values in
  JSON. Since go-fed does not differentiate between 'null' values and
  values that are simply not present, the 'rawJSON' map is ONLY needed
  for this narrow and specific use case.

  GetOutbox returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  AuthenticateGetOutbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  @callback post_outbox(
              context :: context(),
              activity :: struct(),
              outbox_iri :: URI.t(),
              raw_json :: map()
            ) ::
              {:ok, ordered_collection :: struct} | {:error, term()}
end
