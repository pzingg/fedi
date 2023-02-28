ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(FediServer.Repo, :manual)

# Oauth testing
Mox.defmock(Boruta.OauthMock, for: Boruta.OauthModule)
Mox.defmock(Boruta.OpenidMock, for: Boruta.OpenidModule)
