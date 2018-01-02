defmodule Passport.Confirmable do
  import Ecto.Changeset
  import Ecto.Query

  defmacro schema_fields do
    quote do
      field :confirmation_token, :string
      field :confirmed_at, :utc_datetime
      field :confirmation_sent_at, :utc_datetime
    end
  end

  defmacro routes do
    quote do
      # Confirm user email
      post "/confirm/:token", ConfirmationController, :confirm
    end
  end

  def migration_fields(_mod) do
    [
      "# Confirmable",
      "add :confirmation_token, :string",
      "add :confirmed_at, :utc_datetime",
      "add :confirmation_sent_at, :utc_datetime",
    ]
  end

  def migration_indices(_mod) do
    # <users> will be replaced with the correct table name
    [
      "create unique_index(<users>, [:confirmation_token])"
    ]
  end

  alias Passport.Keygen

  def generate_confirmation_token do
    Keygen.random_string(128)
  end

  def confirm(changeset) do
    changeset
    |> put_change(:confirmation_token, nil)
    |> put_change(:confirmation_sent_at, nil)
    |> put_change(:confirmed_at, DateTime.utc_now())
  end

  def prepare_confirmation(changeset) do
    changeset
    |> put_change(:confirmation_token, generate_confirmation_token())
    |> put_change(:confirmation_sent_at, DateTime.utc_now())
    |> put_change(:confirmed_at, nil)
  end

  def by_confirmation_token(query, token) do
    where(query, confirmation_token: ^token)
  end
end
