defmodule FediServer.FixturesHelper do
  @moduledoc false

  alias FediServer.Repo
  alias FediServer.Activities.User
  alias FediServer.Activities.Activity
  alias FediServer.Activities.Object

  def user_fixtures() do
    # Add a remote user
    pzingg =
      with {:ok, contents} <-
             Path.join(:code.priv_dir(:fedi_server), "pzingg.json") |> File.read(),
           {:ok, data} <-
             Jason.decode(contents),
           user <-
             User.new_from_masto_data(data),
           {:ok, _} <-
             User.changeset(user)
             |> Repo.insert(returning: true) do
        user
      else
        _ ->
          nil
      end

    # Add a local user
    endpoint_uri = Fedi.Application.endpoint_url() |> URI.parse()

    alyssa =
      with user <- %User{
             ap_id: %URI{endpoint_uri | path: "/users/alyssa"} |> URI.to_string(),
             inbox: %URI{endpoint_uri | path: "/users/alyssa/inbox"} |> URI.to_string(),
             name: "Alyssa Activa",
             nickname: "alyssa",
             email: "alyssa@example.com",
             local: true,
             data: %{}
           },
           {:ok, _} <-
             User.changeset(user)
             |> Repo.insert(returning: true) do
        user
      else
        _ ->
          nil
      end

    [{:pzingg, pzingg}, {:alyssa, alyssa}]
    |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
    |> Map.new()
  end

  def outbox_fixtures() do
    _ = user_fixtures()

    {:ok, object} =
      %Object{
        id: "01GPQ4DCJTTY4BXYB3ZS989WCC",
        ap_id: "https://example.com/users/alyssa/objects/01GPQ4DCJTTY4BXYB3ZS989WCC",
        type: "Note",
        actor: "https://example.com/users/alyssa",
        local: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "attributedTo" => "https://example.com/users/alyssa",
          "content" => "Say, did you finish reading that book I lent you?",
          "id" => "https://example.com/users/alyssa/objects/01GPQ4DCJTTY4BXYB3ZS989WCC",
          "to" => [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://chatty.example/users/ben"
          ],
          "type" => "Note"
        }
      }
      |> Object.changeset()
      |> Repo.insert(returning: true)

    {:ok, create} =
      %Activity{
        id: "01GPQ4DCJTWE0TZ2GENB8BZMK5",
        ap_id: "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK5",
        type: "Create",
        actor: "https://example.com/users/alyssa",
        recipients: [
          "https://www.w3.org/ns/activitystreams#Public",
          "https://chatty.example/users/ben"
        ],
        local: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "actor" => "https://example.com/users/alyssa",
          "id" => "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK5",
          "object" => %{
            "attributedTo" => "https://example.com/users/alyssa",
            "content" => "Say, did you finish reading that book I lent you?",
            "id" => "https://example.com/users/alyssa/objects/01GPQ4DCJTTY4BXYB3ZS989WCC",
            "to" => [
              "https://www.w3.org/ns/activitystreams#Public",
              "https://chatty.example/users/ben"
            ],
            "type" => "Note"
          },
          "to" => [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://chatty.example/users/ben"
          ],
          "type" => "Create"
        }
      }
      |> Activity.changeset()
      |> Repo.insert(returning: true)

    # {"id", id_prop},
    # {"formerType", former_type},
    # {"published", published},
    # {"updated", updated},
    # {"deleted", deleted}

    {:ok, tombstone_object} =
      %Object{
        id: "01GPQ4DCJTTY4BXYB3ZS989WCC",
        ap_id: "https://example.com/users/alyssa/objects/01GPQ4DCJTTY4BXYB3ZS989WCC",
        type: "Note",
        actor: "https://example.com/users/alyssa",
        local: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "attributedTo" => "https://example.com/users/alyssa",
          "content" => "Say, did you finish reading that book I lent you?",
          "id" => "https://example.com/users/alyssa/objects/01GPQ4DCJTTY4BXYB3ZS989WCC",
          "to" => [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://chatty.example/users/ben"
          ],
          "type" => "Note"
        }
      }
      |> Object.changeset()
      |> Repo.insert(returning: true)

    {:ok, tombstone_activity} =
      %Activity{
        id: "01GPQ4DCJTWE0TZ2GENB8BZMK6",
        ap_id: "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK6",
        type: "Create",
        actor: "https://example.com/users/alyssa",
        recipients: [
          "https://www.w3.org/ns/activitystreams#Public",
          "https://chatty.example/users/ben"
        ],
        local: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "actor" => "https://example.com/users/alyssa",
          "id" => "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK6",
          "object" => %{
            "formerType" => "Note",
            "deleted" => "GMT",
            "attributedTo" => "https://example.com/users/alyssa",
            "content" => "Say, did you finish reading that book I lent you?",
            "id" => "https://example.com/users/alyssa/objects/01GPQ4DCJTTY4BXYB3ZS989WCC",
            "to" => [
              "https://www.w3.org/ns/activitystreams#Public",
              "https://chatty.example/users/ben"
            ],
            "type" => "Tombstone"
          },
          "to" => [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://chatty.example/users/ben"
          ],
          "type" => "Create"
        }
      }
      |> Activity.changeset()
      |> Repo.insert(returning: true)

    {[create], [object]}
  end
end
