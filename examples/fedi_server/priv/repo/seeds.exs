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

{:ok, contents} = Path.join(:code.priv_dir(:fedi_server), "pzingg.json") |> File.read()
{:ok, data} = Jason.decode(contents)

User.new_from_masto_data(data)
|> User.changeset()
|> Repo.insert!()

%User{
  ap_id: "https://example.com/users/alyssa",
  inbox: "https://example.com/users/alyssa/inbox",
  name: "Alyssa Activa",
  nickname: "alyssa",
  email: "alyssa@example.com",
  local: true,
  data: %{}
}
|> User.changeset()
|> Repo.insert!()
