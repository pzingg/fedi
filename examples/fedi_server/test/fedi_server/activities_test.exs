defmodule FediServer.ActivitiesTest do
  use FediServer.DataCase

  alias Fedi.Streams.Utils
  alias FediServer.Activities

  describe "Fixtures" do
    test "user_agent is configured" do
      assert Application.get_env(:fedi_server, :user_agent) == "(elixir-fedi-0.1.0)"
    end

    test "inserts local and federated users" do
      users = FediServer.FixturesHelper.user_fixtures()
      assert users.pzingg.nickname == "pzingg"
      assert users.alyssa.nickname == "alyssa"
    end
  end

  describe "Activities callbacks" do
    test "fails to get Alyssa from an empty database" do
      assert {:error, "Not found"} =
               "https://example.com/users/alyssa"
               |> URI.parse()
               |> Activities.get()
    end

    test "gets Alyssa from a seeded database" do
      _users = FediServer.FixturesHelper.user_fixtures()

      assert {:ok, alyssa} =
               "https://example.com/users/alyssa"
               |> URI.parse()
               |> Activities.get()

      assert alyssa.__struct__ == Fedi.ActivityStreams.Type.Person
      assert Utils.get_json_ld_id(alyssa) |> URI.to_string() == "https://example.com/users/alyssa"
    end
  end
end
