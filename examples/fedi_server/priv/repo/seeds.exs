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

alias FediServer.Repo
alias FediServer.Activities
alias FediServer.Activities.User

# Add a remote user
{:ok, contents} = Path.join(:code.priv_dir(:fedi_server), "pzingg.json") |> File.read()
{:ok, data} = Jason.decode(contents)

User.new_from_masto_data(data)
|> User.changeset()
|> Repo.insert!()

# Add a local user
endpoint_uri = Fedi.Application.endpoint_url() |> URI.parse()

%User{
  ap_id: %URI{endpoint_uri | path: "/users/alyssa"} |> URI.to_string(),
  inbox: %URI{endpoint_uri | path: "/users/alyssa/inbox"} |> URI.to_string(),
  name: "Alyssa Activa",
  nickname: "alyssa",
  email: "alyssa@example.com",
  local: true,
  data: %{}
}
|> User.changeset()
|> Repo.insert!()
