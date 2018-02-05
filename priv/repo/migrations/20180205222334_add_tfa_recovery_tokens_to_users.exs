defmodule Passport.Support.Repo.Migrations.AddTfaRecoveryTokensToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tfa_recovery_tokens, {:array, :string}, default: []
    end
  end
end
