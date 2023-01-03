defmodule Fedi.ActivityPub.ActorBehavior do
  @moduledoc """
  ActorBehavior contains the detailed interface an application must satisfy in
  order to implement the ActivityPub specification.

  Note that an implementation of this interface is implicitly provided in the
  calls to new_actor, new_social_actor, and new_federating_actor.

  Implementing the ActorBehavior requires familiarity with the ActivityPub
  specification because it does not a strong enough abstraction for the client
  application to ignore the ActivityPub spec. It is very possible to implement
  this interface and build a foot-gun that trashes the fediverse without being
  ActivityPub compliant. Please use with due consideration.

  Alternatively, build an application that uses the parts of the pub library
  that do not require implementing a ActorBehavior so that the ActivityPub
  implementation is completely provided out of the box.
  """

  @type actor() :: Fedi.ActivityPub.Actor.context()

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
  @callback inbox_forwarding(actor :: actor(), inbox_iri :: URI.t(), activity :: term()) ::
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

  If the error is ErrObjectRequired or ErrTargetRequired, then a Bad
  Request status is sent in the response.

  Note that 'raw_json' is an unfortunate consequence where an 'Update'
  Activity is the only one that explicitly cares about 'null' values in
  JSON. Since go-fed does not differentiate between 'null' values and
  values that are simply not present, the 'raw_json' map is ONLY needed
  for this narrow and specific use case.
  """
  @callback post_outbox(
              actor :: actor(),
              activity :: term(),
              outbox_iri :: URI.t(),
              raw_json :: map()
            ) ::
              {:ok, deliverable :: boolean()} | {:error, term()}

  @doc """
  add_new_ids sets new URL ids on the activity. It also does so for all
  'object' properties if the Activity is a Create type.

  Only called if the Social API is enabled.

  If an error is returned, it is returned to the caller of post_outbox.
  """
  @callback add_new_ids(actor :: actor(), activity :: term()) ::
              {:ok, activity :: term()} | {:error, term()}

  @doc """
  deliver sends a federated message. Called only if federation is
  enabled.

  Called if the Federated Protocol is enabled.

  The provided url is the outbox of the sender. The Activity contains
  the information about the intended recipients.

  If an error is returned, it is returned to the caller of post_outbox.
  """
  @callback deliver(actor :: actor(), outbox :: URI.t(), activity :: term()) ::
              :ok | {:error, term()}

  @doc """
  wrap_in_create wraps the provided object in a Create ActivityStreams
  activity. The provided URL is the actor's outbox endpoint.

  Only called if the Social API is enabled.
  """
  @callback wrap_in_create(actor :: actor(), value :: term(), outbox_iri :: URI.t()) ::
              {:ok, create :: term()} | {:error, term()}
end
