defmodule Passport.Support.Repo do
  use Ecto.Repo, otp_app: :passport, adapter: Ecto.Adapters.Postgres
end
