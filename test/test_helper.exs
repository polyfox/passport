ExUnit.start()

{:ok, _pid} = Passport.Support.Application.start(:permanent, [])
Ecto.Adapters.SQL.Sandbox.mode(Passport.Support.Repo, :manual)
