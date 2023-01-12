defmodule FediServer.FixturesHelper do
  @moduledoc false

  alias FediServer.Repo
  alias FediServer.Activities.User

  def user_fixtures() do
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

    alyssa =
      with user <- %User{
             ap_id: "http://example.com/users/alyssa",
             inbox: "http://example.com/users/alyssa/inbox",
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
end
