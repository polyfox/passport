defmodule Passport.Support.Repo.Migrations.ChangeTfaOtpSecretKeyIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:users, [:tfa_otp_secret_key])
    create unique_index(:users, [:tfa_otp_secret_key], where: "tfa_otp_secret_key IS NOT NULL")
  end
end
