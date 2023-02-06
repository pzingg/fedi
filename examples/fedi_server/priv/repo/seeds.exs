# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FediServer.Repo.insert!(%FediServer.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Fedi.Streams.Utils
alias FediServer.Repo
alias FediServer.Accounts.User

# Add a remote user
{:ok, contents} = Path.join(:code.priv_dir(:fedi_server), "ben.json") |> File.read()
{:ok, data} = Jason.decode(contents)

User.new_remote_user(data)
|> User.changeset()
|> Repo.insert!()

# Add a local user
endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()
shared_inbox_uri = %URI{endpoint_uri | path: "/inbox"} |> URI.to_string()

%User{
  ap_id: %URI{endpoint_uri | path: "/users/alyssa"} |> URI.to_string(),
  inbox: %URI{endpoint_uri | path: "/users/alyssa/inbox"} |> URI.to_string(),
  name: "Alyssa Activa",
  nickname: "alyssa",
  email: "alyssa@example.com",
  password: "pass",
  local?: true,
  shared_inbox: shared_inbox_uri,
  on_follow: :automatically_accept,
  data: %{}
}
|> User.changeset()
|> Repo.insert!()
