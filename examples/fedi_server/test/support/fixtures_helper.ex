defmodule FediServer.FixturesHelper do
  @moduledoc false

  import Ecto.Query

  require Logger

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
           {:ok, private_key_json} <-
             Path.join(:code.priv_dir(:fedi_server), "ben_private_key.json") |> File.read(),
           {:ok, private_key} <-
             Jason.decode(private_key_json),
           {:ok, contents} <-
             Path.join(:code.priv_dir(:fedi_server), "ben.json") |> File.read(),
           {:ok, data} <-
             Jason.decode(contents),
           %User{} = user <-
             User.new_remote_user(data),
           {:ok, user} <-
             User.changeset(user)
             |> Repo.insert(returning: true) do
        {user, private_key}
      else
        other ->
          Logger.error("Problem making ben: #{inspect(other)}")
          {nil, nil}
      end

    # Add a remote user
    {charlie, charlie_private_key_pem} =
      with false <- Keyword.get(opts, :local_only, false),
           {:ok, private_key_json} <-
             Path.join(:code.priv_dir(:fedi_server), "charlie_private_key.json") |> File.read(),
           {:ok, private_key} <-
             Jason.decode(private_key_json),
           {:ok, contents} <-
             Path.join(:code.priv_dir(:fedi_server), "charlie.json") |> File.read(),
           {:ok, data} <-
             Jason.decode(contents),
           %User{} = user <-
             User.new_remote_user(data),
           {:ok, user} <-
             User.changeset(user)
             |> Repo.insert(returning: true) do
        {user, private_key}
      else
        other ->
          Logger.error("Problem making charlie: #{inspect(other)}")
          {nil, nil}
      end

    # Add a remote user
    {emilia, emilia_private_key_pem} =
      with false <- Keyword.get(opts, :local_only, false),
           {:ok, private_key_json} <-
             Path.join(:code.priv_dir(:fedi_server), "emilia_private_key.json") |> File.read(),
           {:ok, private_key} <-
             Jason.decode(private_key_json),
           {:ok, contents} <-
             Path.join(:code.priv_dir(:fedi_server), "emilia.json") |> File.read(),
           {:ok, data} <-
             Jason.decode(contents),
           %User{} = user <-
             User.new_remote_user(data),
           {:ok, user} <-
             User.changeset(user)
             |> Repo.insert(returning: true) do
        {user, private_key}
      else
        other ->
          Logger.error("Problem making emilia: #{inspect(other)}")
          {nil, nil}
      end

    # Add a local user
    endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()
    shared_inbox_uri = Utils.base_uri(endpoint_uri, "/inbox") |> URI.to_string()

    alyssa =
      with false <- Keyword.get(opts, :remote_only, false),
           user <- %User{
             ap_id: Utils.base_uri(endpoint_uri, "/users/alyssa") |> URI.to_string(),
             inbox: Utils.base_uri(endpoint_uri, "/users/alyssa/inbox") |> URI.to_string(),
             name: "Alyssa Activa",
             nickname: "alyssa",
             email: "alyssa@example.com",
             password: "pass",
             local?: true,
             shared_inbox: shared_inbox_uri,
             on_follow: :automatically_accept,
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
             ap_id: Utils.base_uri(endpoint_uri, "/users/daria") |> URI.to_string(),
             inbox: Utils.base_uri(endpoint_uri, "/users/daria/inbox") |> URI.to_string(),
             name: "Daria Daring",
             nickname: "daria",
             email: "daria@example.com",
             password: "pass",
             local?: true,
             shared_inbox: shared_inbox_uri,
             on_follow: :automatically_reject,
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
      {:charlie, %{user: charlie, keys: charlie_private_key_pem}},
      {:emilia, %{user: emilia, keys: emilia_private_key_pem}},
      {:alyssa, %{user: alyssa}},
      {:daria, %{user: daria}}
    ]
    |> Enum.filter(fn {_k, v} -> !is_nil(v.user) end)
    |> Map.new()
  end

  def following_fixtures() do
    %{ben: %{user: ben}, alyssa: %{user: alyssa}} = users = user_fixtures()

    Activities.follow(alyssa.ap_id, ben.ap_id)
    users
  end

  def followers_fixtures() do
    %{ben: %{user: ben}, alyssa: %{user: alyssa}} = users = user_fixtures()

    Activities.follow(ben.ap_id, alyssa.ap_id)
    users
  end

  # note1: attributed to alyssa, public
  # note2: attributed to alyssa, public, tombstoned
  # note3: attributed to daria, followers_only
  def outbox_fixtures() do
    users = user_fixtures()
    actor_alyssa = "https://example.com/users/alyssa"
    actor_daria = "https://example.com/users/daria"

    note1_id = "01GPQ4DCJTTY4BXYB3ZS989WCC"
    note1_ap_id = "https://example.com/users/alyssa/objects/#{note1_id}"

    {:ok, note1_data} =
      %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Note",
        "id" => note1_ap_id,
        "to" => "https://chatty.example/users/ben",
        "content" =>
          "Say, did you finish reading that **book** I lent you and @charlie@other.example?",
        "mediaType" => "text/markdown",
        "attributedTo" => actor_alyssa
      }
      |> Fedi.Content.set_tags()

    note1_data = Fedi.Client.set_visibility(note1_data, :public)

    note1_recipient_params = Activities.canonical_recipients(note1_data["to"])

    {:ok, note1} =
      %Object{
        id: note1_id,
        ap_id: note1_ap_id,
        type: note1_data["type"],
        actor: note1_data["attributedTo"],
        local?: true,
        data: note1_data
      }
      |> Object.changeset(note1_recipient_params)
      |> Repo.insert(returning: true)

    create1_ap_id = "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK5"
    create1_recipient_params = Activities.canonical_recipients(note1_data["to"])

    {:ok, create1} =
      %Activity{
        id: "01GPQ4DCJTWE0TZ2GENB8BZMK5",
        ap_id: create1_ap_id,
        type: "Create",
        actor: actor_alyssa,
        object: note1_ap_id,
        local?: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "actor" => actor_alyssa,
          "id" => create1_ap_id,
          "object" => note1_data,
          "to" => note1_data["to"],
          "type" => "Create"
        }
      }
      |> Activity.changeset(create1_recipient_params)
      |> Repo.insert(returning: true)

    note2_id = "01GPRE6K5J0ZCY63TAVM35D2SQ"
    note2_ap_id = "https://example.com/users/alyssa/objects/#{note2_id}"

    note2_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "attributedTo" => actor_alyssa,
      "content" => "That was a great read!",
      "mediaType" => "text/markdown",
      "id" => note2_ap_id,
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "https://chatty.example/users/ben"
      ],
      "type" => "Note"
    }

    note2_recipient_params = Activities.canonical_recipients(note2_data["to"])

    {:ok, _note2} =
      %Object{
        id: note2_id,
        ap_id: note2_ap_id,
        type: note2_data["type"],
        actor: actor_alyssa,
        local?: true,
        data: note2_data
      }
      |> Object.changeset(note2_recipient_params)
      |> Repo.insert(returning: true)

    create2_ap_id = "https://example.com/users/alyssa/activities/01GPRE7X6JVPGKH3AW39K2YAJB"

    create2_recipient_params = Activities.canonical_recipients(note2_data["to"])

    {:ok, create2} =
      %Activity{
        id: "01GPRE7X6JVPGKH3AW39K2YAJB",
        ap_id: create2_ap_id,
        type: "Create",
        actor: actor_alyssa,
        object: note2_ap_id,
        local?: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "actor" => actor_alyssa,
          "id" => create2_ap_id,
          "object" => note2_data,
          "to" => note2_data["to"],
          "type" => "Create"
        }
      }
      |> Activity.changeset(create2_recipient_params)
      |> Repo.insert(returning: true)

    note3_id = "01GQ6GVPMRQF4T4B5QKZCF0HTG"
    note3_ap_id = "https://example.com/users/daria/objects/#{note3_id}"

    note3_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "attributedTo" => actor_daria,
      "content" => "My favorite read of the year.",
      "mediaType" => "text/markdown",
      "id" => note3_ap_id,
      "to" => "https://example.com/users/daria/followers",
      "type" => "Note"
    }

    note3_recipient_params = Activities.canonical_recipients(note3_data["to"])

    {:ok, note3} =
      %Object{
        id: note3_id,
        ap_id: note3_ap_id,
        type: note3_data["type"],
        actor: actor_daria,
        local?: true,
        data: note3_data
      }
      |> Object.changeset(note3_recipient_params)
      |> Repo.insert(returning: true)

    create3_recipient_params = Activities.canonical_recipients(note3_data["to"])

    create3_ap_id = "https://example.com/users/daria/activities/01GQ6GWFZ0ZACCMD5Y1TSV4F07"

    {:ok, create3} =
      %Activity{
        id: "01GQ6GWFZ0ZACCMD5Y1TSV4F07",
        ap_id: create3_ap_id,
        type: "Create",
        actor: actor_daria,
        object: note3_ap_id,
        local?: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "actor" => actor_daria,
          "id" => create3_ap_id,
          "object" => note3_data,
          "to" => note3_data["to"],
          "type" => "Create"
        }
      }
      |> Activity.changeset(create3_recipient_params)
      |> Repo.insert(returning: true)

    # QUESTION: should the tombstone object always be addressed to the original object's audience?
    tombstone_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => note2_ap_id,
      "formerType" => "Note",
      "deleted" => "Sat, 14 Jan 2023 15:35:13 GMT",
      "type" => "Tombstone",
      "to" => note2_data["to"]
    }

    # No change to actor, recipients, or local
    tombstone_params =
      %{
        ap_id: note2_ap_id,
        type: "Tombstone",
        actor: actor_alyssa,
        local?: true,
        data: tombstone_data
      }
      |> Map.merge(note2_recipient_params)

    {:ok, tombstone} =
      %Object{id: note2_id}
      |> Object.changeset(tombstone_params)
      |> Repo.update(returning: true)

    delete2_recipient_params = Activities.canonical_recipients(note2_data["to"])

    delete2_ap_id = "https://example.com/users/alyssa/activities/01GPRETMR3D01FM26ZHRZVQYWZ"

    {:ok, delete2} =
      %Activity{
        id: "01GPRETMR3D01FM26ZHRZVQYWZ",
        ap_id: delete2_ap_id,
        type: "Delete",
        actor: actor_alyssa,
        object: note2_ap_id,
        local?: true,
        data: %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "actor" => actor_alyssa,
          "id" => delete2_ap_id,
          "object" => tombstone_data,
          "to" => note2_data["to"],
          "type" => "Delete"
        }
      }
      |> Activity.changeset(delete2_recipient_params)
      |> Repo.insert(returning: true)

    {users, [create1, create2, create3, delete2], [note1, note3, tombstone]}
  end
end
