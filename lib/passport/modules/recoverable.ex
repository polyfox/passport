defmodule Passport.Recoverable do
  import Ecto.Changeset
  import Ecto.Query
  alias Passport.Keygen

  # for now
  @type t :: term

  defmacro schema_fields do
    quote do
      field :reset_password_token, :string
      field :reset_password_sent_at, :utc_datetime
    end
  end

  defmacro routes(opts \\ []) do
    recoverable_controller = Keyword.get(opts, :recoverable_controller, PasswordController)
    quote do
      # Request a password reset
      post "/password", unquote(recoverable_controller), :create
      # Reset password - pick your poison (by verb)
      post "/password/:token", unquote(recoverable_controller), :update
      patch "/password/:token", unquote(recoverable_controller), :update
      put "/password/:token", unquote(recoverable_controller), :update
      # Clear reset password
      delete "/password/:token", unquote(recoverable_controller), :delete
    end
  end

  def migration_fields(_mod) do
    [
      "# Recoverable",
      "add :reset_password_token, :string",
      "add :reset_password_sent_at, :utc_datetime",
    ]
  end

  def migration_indices(_mod) do
    # <users> will be replaced with the correct table name
    [
      "create unique_index(<users>, [:reset_password_token])"
    ]
  end

  def generate_reset_password_token do
    Keygen.random_string(128)
  end

  def clear_reset_password(changeset) do
    changeset
    |> put_change(:reset_password_token, nil)
    |> put_change(:reset_password_sent_at, nil)
  end

  def prepare_reset_password(changeset) do
    changeset
    |> put_change(:reset_password_token, generate_reset_password_token())
    |> put_change(:reset_password_sent_at, DateTime.utc_now())
  end

  def by_reset_password_token(query, token) do
    where(query, reset_password_token: ^token)
  end
end
