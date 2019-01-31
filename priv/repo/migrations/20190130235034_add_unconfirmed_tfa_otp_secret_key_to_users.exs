defmodule Passport.Support.Repo.Migrations.AddUnconfirmedTfaOtpSecretKeyToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :unconfirmed_tfa_otp_secret_key, :string
    end
  end
end
