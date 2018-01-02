use Mix.Config

config :passport,
  primary_repo: nil,
  replica_repo: nil

import_config "#{Mix.env()}.exs"
