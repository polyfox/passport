use Mix.Config

config :passport,
  primary_repo: nil,
  replica_repo: nil

config :passport,
  password_hash_field: :password_hash

import_config "#{Mix.env()}.exs"
