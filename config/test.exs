use Mix.Config

config :passport, ecto_repos: [Passport.Support.Repo]
config :passport, Passport.Support.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool_size: 10,
  username: "postgres",
  password: "postgres",
  database: "passport_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :passport,
  primary_repo: Passport.Support.Repo,
  replica_repo: Passport.Support.Repo
