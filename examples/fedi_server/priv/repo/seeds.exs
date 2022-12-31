# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FediServer.Repo.insert!(%FediServer.SomeSchema{})
#
# We resocialmend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias FediServer.Repo
alias FediServer.Activities.User

Repo.insert!(%User{
  ap_id: "http://example.social/users/gargron",
  inbox: "http://example.social/users/gargron/inbox",
  name: "Eugen Rochko",
  nickname: "gargron",
  email: "gargron@example.social",
  local: true,
  data: %{}
})
