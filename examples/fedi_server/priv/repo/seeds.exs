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
shared_inbox_uri = Utils.base_uri(endpoint_uri, "/inbox") |> URI.to_string()

%User{
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
}
|> User.changeset()
|> Repo.insert!()

# Add an Oauth client
id = SecureRandom.uuid()
secret = SecureRandom.hex(64)

{:ok, _client} =
  Boruta.Ecto.Admin.create_client(%{
    # OAuth client_id
    id: id,
    # OAuth client_secret
    secret: secret,
    # Display name
    name: "fedi-server-oauth-client",
    # one day
    access_token_ttl: 60 * 60 * 24,
    # one minute
    authorization_code_ttl: 60,
    # one month
    refresh_token_ttl: 60 * 60 * 24 * 30,
    # one day
    id_token_ttl: 60 * 60 * 24,
    # ID token signature algorithm, defaults to "RS512"
    id_token_signature_alg: "RS256",
    # OAuth client redirect_uris
    redirect_uris: ["http://localhost:4000"],
    # take following authorized_scopes into account (skip public scopes)
    authorize_scope: true,
    # scopes that are authorized using this client
    authorized_scopes: [%{name: "read"}, %{name: "write"}],
    # client supported grant types
    supported_grant_types: [
      "client_credentials",
      "password",
      "authorization_code",
      "refresh_token",
      "implicit",
      "revoke",
      "introspect"
    ],
    # PKCE enabled
    pkce: false,
    # do not require client_secret for refreshing tokens
    public_refresh_token: false,
    # do not require client_secret for revoking tokens
    public_revoke: false
  })
