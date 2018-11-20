defmodule Passport.Support.Repo.Migrations.AddPassportFieldsToPassportSupportUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Activatable
      add :active, :boolean, default: true
      # Authenticatable
      add :password_hash, :string, null: false
      # Confirmable
      add :confirmation_token, :string
      add :confirmed_at, :utc_datetime_usec
      add :confirmation_sent_at, :utc_datetime_usec
      # Lockable
      add :failed_attempts, :integer, default: 0
      add :locked_at, :utc_datetime_usec
      # Recoverable
      add :reset_password_token, :string
      add :reset_password_sent_at, :utc_datetime_usec
      # Rememberable
      add :remember_created_at, :utc_datetime_usec
      # Trackable
      add :sign_in_count, :integer, default: 0
      add :current_sign_in_at, :utc_datetime_usec
      add :current_sign_in_ip, :string
      add :last_sign_in_at, :utc_datetime_usec
      add :last_sign_in_ip, :string
      # TwoFactorAuth
      add :tfa_otp_secret_key, :string
      add :tfa_enabled, :boolean
      add :tfa_attempts_count, :integer, default: 0
    end

    create unique_index(:users, [:confirmation_token])
    create unique_index(:users, [:reset_password_token])
    create unique_index(:users, [:tfa_otp_secret_key])
  end
end
