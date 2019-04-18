use Mix.Config

config :bcrypt_elixir,
  log_rounds: 4

config :passport,
  error_view: Passport.Support.Web.ErrorView,
  sessions_client: Passport.Support.Sessions

# Configures the endpoint
config :passport, Passport.Support.Web.Endpoint,
  url: [host: "localhost", port: 4001],
  secret_key_base: "nVOH69Esw7w6+UinScaJ+LIsUzs4j+lfgM3Ogpp5/8UEN8//N9ekht6UuXzjAhOZ",
  render_errors: [view: Passport.Support.Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Passport.Support.PubSub,
           adapter: Phoenix.PubSub.PG2],
  server: false

config :passport, ecto_repos: [Passport.Support.Repo]
config :passport, Passport.Support.Repo,
  pool_size: 10,
  username: "postgres",
  password: "postgres",
  database: "passport_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :passport,
  primary_repo: Passport.Support.Repo,
  replica_repo: Passport.Support.Repo

config :logger, level: :warn

config :phoenix, :json_library, Jason
