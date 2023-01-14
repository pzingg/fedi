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

    {:ok, note} =
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

    {:ok, create1} =
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

    {:ok, _note2} =
      %Object{
        id: "01GPRE6K5J0ZCY63TAVM35D2SQ",
        ap_id: "https://example.com/users/alyssa/objects/01GPRE6K5J0ZCY63TAVM35D2SQ",
        type: "Note",
        actor: "https://example.com/users/alyssa",
        local: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "attributedTo" => "https://example.com/users/alyssa",
          "content" => "That was a great read!",
          "id" => "https://example.com/users/alyssa/objects/01GPRE6K5J0ZCY63TAVM35D2SQ",
          "to" => [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://chatty.example/users/ben"
          ],
          "type" => "Note"
        }
      }
      |> Object.changeset()
      |> Repo.insert(returning: true)

    {:ok, create2} =
      %Activity{
        id: "01GPRE7X6JVPGKH3AW39K2YAJB",
        ap_id: "https://example.com/users/alyssa/activities/01GPRE7X6JVPGKH3AW39K2YAJB",
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
          "id" => "https://example.com/users/alyssa/activities/01GPRE7X6JVPGKH3AW39K2YAJB",
          "object" => %{
            "attributedTo" => "https://example.com/users/alyssa",
            "content" => "That was a great read!",
            "id" => "https://example.com/users/alyssa/objects/01GPRE6K5J0ZCY63TAVM35D2SQ",
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

    tombstone_params = %{
      ap_id: "https://example.com/users/alyssa/objects/01GPRE6K5J0ZCY63TAVM35D2SQ",
      type: "Tombstone",
      actor: "https://example.com/users/alyssa",
      local: true,
      data: %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "id" => "https://example.com/users/alyssa/objects/01GPRE6K5J0ZCY63TAVM35D2SQ",
        "formerType" => "Note",
        "deleted" => "Sat, 14 Jan 2023 15:35:13 GMT",
        "type" => "Tombstone"
      }
    }

    {:ok, tombstone} =
      %Object{id: "01GPRE6K5J0ZCY63TAVM35D2SQ"}
      |> Object.changeset(tombstone_params)
      |> Repo.update(returning: true)

    {:ok, delete2} =
      %Activity{
        id: "01GPRETMR3D01FM26ZHRZVQYWZ",
        ap_id: "https://example.com/users/alyssa/activities/01GPRETMR3D01FM26ZHRZVQYWZ",
        type: "Delete",
        actor: "https://example.com/users/alyssa",
        recipients: [
          "https://www.w3.org/ns/activitystreams#Public",
          "https://chatty.example/users/ben"
        ],
        local: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "actor" => "https://example.com/users/alyssa",
          "id" => "https://example.com/users/alyssa/activities/01GPRETMR3D01FM26ZHRZVQYWZ",
          "object" => %{
            "id" => "https://example.com/users/alyssa/objects/01GPRE6K5J0ZCY63TAVM35D2SQ",
            "formerType" => "Note",
            "deleted" => "Sat, 14 Jan 2023 15:35:13 GMT",
            "type" => "Tombstone"
          },
          "to" => [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://chatty.example/users/ben"
          ],
          "type" => "Delete"
        }
      }
      |> Activity.changeset()
      |> Repo.insert(returning: true)

    {[create1, create2, delete2], [note, tombstone]}
  end
end
