defmodule FediServer.FixturesHelper do
  @moduledoc false

  alias FediServer.Repo
  alias FediServer.Activities.User

  def user_fixtures() do
    app_agent = Application.fetch_env!(:fedi_server, :user_agent)

    {:ok, pzingg} =
      "https://mastodon.cloud/users/pzingg"
      |> URI.parse()
      |> User.parse_federated_user(app_agent)
      |> User.changeset()
      |> Repo.insert(returning: true)

    {:ok, alyssa} =
      %User{
        ap_id: "http://example.com/users/alyssa",
        inbox: "http://example.com/users/alyssa/inbox",
        name: "Alyssa Activa",
        nickname: "alyssa",
        email: "alyssa@example.com",
        local: true,
        data: %{}
      }
      |> User.changeset()
      |> Repo.insert(returning: true)

    %{pzingg: pzingg, alyssa: alyssa}
  end
end
