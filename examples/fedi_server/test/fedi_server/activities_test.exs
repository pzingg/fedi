defmodule FediServer.ActivitiesTest do
  use FediServer.DataCase

  import FediServer.FixturesHelper

  alias Fedi.Streams.Utils
  alias FediServer.Activities
  alias FediServer.Activities.Object

  describe "Fixtures" do
    test "user_agent is configured" do
      assert Application.get_env(:fedi, :user_agent) == "(elixir-fedi-server-0.1.0)"
    end

    test "inserts local and federated users" do
      users = FediServer.FixturesHelper.user_fixtures()
      assert users.ben.user.nickname == "ben"
      assert users.alyssa.user.nickname == "alyssa"
    end
  end

  describe "Conversations" do
    test "adds notes in reply to other notes" do
      {_users, _activities, [in_reply_to | _]} = outbox_fixtures()

      fixture_ap_ids =
        Object
        |> Repo.all()
        |> Enum.map(fn %{ap_id: ap_id} -> ap_id end)
        |> Enum.sort()

      actor_alyssa = "https://example.com/users/alyssa"
      actor_daria = "https://example.com/users/daria"

      child1_id = "01GRQ2PSPVBQARJB1NN97H2ZTQ"
      child1_ap_id = "#{actor_alyssa}/objects/#{child1_id}"

      child1_data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "attributedTo" => actor_alyssa,
        "content" => "Yes, I finished my own book!",
        "id" => child1_ap_id,
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public",
          "https://chatty.example/users/ben"
        ],
        "inReplyTo" => in_reply_to.ap_id,
        "type" => "Note"
      }

      child1_recipient_params =
        Activities.canonical_recipients(child1_data["to"])
        |> Map.put(:in_reply_to_id, child1_data["inReplyTo"])

      {:ok, child1} =
        %Object{
          id: child1_id,
          ap_id: child1_ap_id,
          type: child1_data["type"],
          actor: child1_data["attributedTo"],
          local?: true,
          data: child1_data
        }
        |> Object.changeset(child1_recipient_params)
        |> Repo.insert(returning: true)

      grandchild2_id = "01GRQ4P9PAFE84ZT24AZ5892TM"
      grandchild2_ap_id = "#{actor_daria}/objects/#{grandchild2_id}"

      grandchild2_data = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "attributedTo" => actor_daria,
        "content" => "Great!",
        "id" => grandchild2_ap_id,
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public",
          "https://chatty.example/users/alyssa"
        ],
        "inReplyTo" => child1.ap_id,
        "type" => "Note"
      }

      grandchild2_recipient_params =
        Activities.canonical_recipients(grandchild2_data["to"])
        |> Map.put(:in_reply_to_id, grandchild2_data["inReplyTo"])

      {:ok, grandchild2} =
        %Object{
          id: grandchild2_id,
          ap_id: grandchild2_ap_id,
          type: grandchild2_data["type"],
          actor: grandchild2_data["attributedTo"],
          local?: true,
          data: grandchild2_data
        }
        |> Object.changeset(grandchild2_recipient_params)
        |> Repo.insert(returning: true)

      all_conversations =
        Object.roots()
        |> Repo.all()
        |> Enum.map(fn %{ap_id: ap_id} -> ap_id end)
        |> Enum.sort()

      # Our new note is not a root
      assert all_conversations == fixture_ap_ids

      %{ap_id: parent} =
        child1
        |> Object.parent()
        |> Repo.one()

      assert parent == in_reply_to.ap_id

      children =
        in_reply_to
        |> Object.children()
        |> Repo.all()
        |> Enum.map(fn %{ap_id: ap_id} -> ap_id end)
        |> Enum.sort()

      assert children == [child1_ap_id]

      descendants =
        in_reply_to
        |> Object.descendants()
        |> Repo.all()
        |> Enum.map(fn %{ap_id: ap_id} -> ap_id end)
        |> Enum.sort()

      assert descendants == [child1_ap_id, grandchild2_ap_id]

      %{ap_id: conversation} =
        grandchild2
        |> Object.ancestors()
        |> Ecto.Query.order_by(:ap_id)
        |> Ecto.Query.limit(1)
        |> Repo.one()

      assert conversation == in_reply_to.ap_id
    end
  end

  describe "Activities callbacks" do
    test "fails to get Alyssa from an empty database" do
      assert {:error, "Not found"} =
               "https://example.com/users/alyssa"
               |> Utils.to_uri()
               |> Activities.get()
    end

    test "gets Alyssa from a seeded database" do
      _users = FediServer.FixturesHelper.user_fixtures()

      assert {:ok, alyssa} =
               "https://example.com/users/alyssa"
               |> Utils.to_uri()
               |> Activities.get()

      assert alyssa.__struct__ == Fedi.ActivityStreams.Type.Person
      assert Utils.get_json_ld_id(alyssa) |> URI.to_string() == "https://example.com/users/alyssa"
    end
  end
end
