defmodule FediServer.VisibilityTest do
  use FediServer.DataCase

  import FediServer.FixturesHelper

  alias Fedi.Streams.Utils
  alias FediServer.Activities

  test "creates public object" do
    %{alyssa: %{user: alyssa}} = user_fixtures()
    {:ok, _activity_id, object_id, _recipient_count} = make_post(alyssa, :public)
    object = Activities.repo_get_by_ap_id(:objects, object_id)
    assert object
    assert object.public?
  end

  test "creates unlisted object" do
    %{alyssa: %{user: alyssa}} = user_fixtures()
    {:ok, _activity_id, object_id, _recipient_count} = make_post(alyssa, :unlisted)
    object = Activities.repo_get_by_ap_id(:objects, object_id)
    assert object
    assert object.public?
  end

  test "creates followers only object" do
    %{alyssa: %{user: alyssa}} = user_fixtures()
    {:ok, _activity_id, object_id, _recipient_count} = make_post(alyssa, :followers_only)
    object = Activities.repo_get_by_ap_id(:objects, object_id)
    assert object
    refute object.public?
  end

  test "creates direct object" do
    %{alyssa: %{user: alyssa}} = user_fixtures()
    {:ok, _activity_id, object_id, _recipient_count} = make_post(alyssa, :direct)
    object = Activities.repo_get_by_ap_id(:objects, object_id)
    assert object
    refute object.public?
  end

  def make_post(user, visibility, content \\ "A post") do
    actor =
      Fedi.ActivityPub.SideEffectActor.new(
        FediServerWeb.SocialCallbacks,
        FediServer.Activities,
        c2s: FediServerWeb.SocialCallbacks,
        s2s: nil,
        current_user: user
      )

    actor = struct(actor, box_iri: Utils.to_uri("#{user.ap_id}/outbox"))
    opts = [visibility: visibility, webfinger_module: FediServerWeb.WebFinger]
    activity = Fedi.Client.post(user.ap_id, content, %{}, opts)
    Fedi.ActivityPub.Actor.post_activity(actor, activity)
  end
end
