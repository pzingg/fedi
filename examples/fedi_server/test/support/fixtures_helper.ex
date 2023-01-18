defmodule FediServer.FixturesHelper do
  @moduledoc false

  alias Fedi.Streams.Utils
  alias FediServer.Repo
  alias FediServer.Activities
  alias FediServer.Accounts.User
  alias FediServer.Activities.Activity
  alias FediServer.Activities.Object

  def user_fixtures(opts \\ []) do
    # Add a remote user
    {ben, ben_private_key_pem} =
      with false <- Keyword.get(opts, :local_only, false),
           {:ok, keys} <-
             Path.join(:code.priv_dir(:fedi_server), "ben_private_key.pem") |> File.read(),
           {:ok, contents} <-
             Path.join(:code.priv_dir(:fedi_server), "ben.json") |> File.read(),
           {:ok, data} <-
             Jason.decode(contents),
           user <-
             User.new_remote_user(data),
           {:ok, user} <-
             User.changeset(user)
             |> Repo.insert(returning: true) do
        {user, keys}
      else
        _ ->
          {nil, nil}
      end

    # Add a local user
    endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()

    alyssa =
      with false <- Keyword.get(opts, :remote_only, false),
           user <- %User{
             ap_id: %URI{endpoint_uri | path: "/users/alyssa"} |> URI.to_string(),
             inbox: %URI{endpoint_uri | path: "/users/alyssa/inbox"} |> URI.to_string(),
             name: "Alyssa Activa",
             nickname: "alyssa",
             email: "alyssa@example.com",
             password: "pass",
             local: true,
             data: %{}
           },
           {:ok, user} <-
             User.changeset(user)
             |> Repo.insert(returning: true) do
        user
      else
        _ ->
          nil
      end

    daria =
      with false <- Keyword.get(opts, :remote_only, false),
           user <- %User{
             ap_id: %URI{endpoint_uri | path: "/users/daria"} |> URI.to_string(),
             inbox: %URI{endpoint_uri | path: "/users/daria/inbox"} |> URI.to_string(),
             name: "Daria Daring",
             nickname: "daria",
             email: "daria@example.com",
             password: "pass",
             local: true,
             data: %{}
           },
           {:ok, user} <-
             User.changeset(user)
             |> Repo.insert(returning: true) do
        user
      else
        _ ->
          nil
      end

    [
      {:ben, %{user: ben, keys: ben_private_key_pem}},
      {:alyssa, %{user: alyssa}},
      {:daria, %{user: daria}}
    ]
    |> Enum.filter(fn {_k, v} -> !is_nil(v.user) end)
    |> Map.new()
  end

  def following_fixtures() do
    %{ben: %{user: ben}, alyssa: %{user: alyssa}} = users = user_fixtures()

    Activities.follow(Utils.to_uri(alyssa.ap_id), Utils.to_uri(ben.ap_id))
    users
  end

  def followers_fixtures() do
    %{ben: %{user: ben}, alyssa: %{user: alyssa}} = users = user_fixtures()

    Activities.follow(Utils.to_uri(ben.ap_id), Utils.to_uri(alyssa.ap_id))
    users
  end

  def outbox_fixtures() do
    users = user_fixtures()

    note1_id = "01GPQ4DCJTTY4BXYB3ZS989WCC"

    note1_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?",
      "id" => "https://example.com/users/alyssa/objects/#{note1_id}",
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "https://chatty.example/users/ben"
      ],
      "type" => "Note"
    }

    {:ok, note1} =
      %Object{
        id: note1_id,
        ap_id: "https://example.com/users/alyssa/objects/#{note1_id}",
        type: "Note",
        actor: "https://example.com/users/alyssa",
        local: true,
        data: note1_data
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
          "object" => note1_data,
          "to" => [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://chatty.example/users/ben"
          ],
          "type" => "Create"
        }
      }
      |> Activity.changeset()
      |> Repo.insert(returning: true)

    note2_id = "01GPRE6K5J0ZCY63TAVM35D2SQ"

    note2_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "That was a great read!",
      "id" => "https://example.com/users/alyssa/objects/#{note2_id}",
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "https://chatty.example/users/ben"
      ],
      "type" => "Note"
    }

    {:ok, _note2} =
      %Object{
        id: note2_id,
        ap_id: "https://example.com/users/alyssa/objects/#{note2_id}",
        type: "Note",
        actor: "https://example.com/users/alyssa",
        local: true,
        data: note2_data
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
          "object" => note2_data,
          "to" => [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://chatty.example/users/ben"
          ],
          "type" => "Create"
        }
      }
      |> Activity.changeset()
      |> Repo.insert(returning: true)

    note3_id = "01GQ6GVPMRQF4T4B5QKZCF0HTG"

    note3_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "attributedTo" => "https://example.com/users/daria",
      "content" => "My favorite read of the year.",
      "id" => "https://example.com/users/daria/objects/#{note3_id}",
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "https://chatty.example/users/ben"
      ],
      "type" => "Note"
    }

    {:ok, note3} =
      %Object{
        id: note3_id,
        ap_id: "https://example.com/users/daria/objects/#{note3_id}",
        type: "Note",
        actor: "https://example.com/users/daria",
        local: true,
        data: note3_data
      }
      |> Object.changeset()
      |> Repo.insert(returning: true)

    {:ok, create3} =
      %Activity{
        id: "01GQ6GWFZ0ZACCMD5Y1TSV4F07",
        ap_id: "https://example.com/users/daria/activities/01GQ6GWFZ0ZACCMD5Y1TSV4F07",
        type: "Create",
        actor: "https://example.com/users/daria",
        recipients: [
          "https://www.w3.org/ns/activitystreams#Public",
          "https://chatty.example/users/ben"
        ],
        local: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "actor" => "https://example.com/users/daria",
          "id" => "https://example.com/users/daria/activities/01GQ6GWFZ0ZACCMD5Y1TSV4F07",
          "object" => note3_data,
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

    {users, [create1, create2, create3, delete2], [note1, note3, tombstone]}
  end
end
