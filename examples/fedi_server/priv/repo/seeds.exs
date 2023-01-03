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
alias FediServer.Activities.User

user_id = URI.parse("https://mastodon.cloud/users/pzingg")
app_agent = Application.fetch_env!(:fedi_server, :user_agent)
%User{} = user = User.parse_federated_user(user_id, app_agent)

user
|> User.changeset()
|> Repo.insert!()

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
|> Repo.insert!()
