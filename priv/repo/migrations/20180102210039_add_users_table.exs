defmodule Passport.Support.Repo.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      timestamps(type: :utc_datetime_usec)

      add :email, :string, null: false
      add :username, :string, null: false
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
