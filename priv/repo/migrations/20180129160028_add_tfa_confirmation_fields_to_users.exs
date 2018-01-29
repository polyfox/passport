defmodule Passport.Support.Repo.Migrations.AddTfaConfirmationFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tfa_confirmation_token, :string
      add :tfa_confirmed_at, :utc_datetime
    end

    create unique_index(:users, [:tfa_confirmation_token])
  end
end
