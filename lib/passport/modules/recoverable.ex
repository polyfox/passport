defmodule Passport.Recoverable do
  import Ecto.Changeset
  import Ecto.Query
  alias Passport.Keygen

  # for now
  @type t :: term

  defmacro schema_fields(options \\ []) do
    timestamp_type = Keyword.get(options, :timestamp_type, :utc_datetime_usec)
    quote do
      field :reset_password_token,   :string
      field :reset_password_sent_at, unquote(timestamp_type)
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
      "add :reset_password_token,   :string",
      "add :reset_password_sent_at, :utc_datetime_usec",
    ]
  end

  def migration_indices(_mod) do
    # <users> will be replaced with the correct table name
    [
      "create unique_index(<users>, [:reset_password_token])"
    ]
  end

  @spec generate_reset_password_token(term) :: String.t
  def generate_reset_password_token(object \\ nil) do
    Keygen.random_string(Passport.Config.reset_password_token_length(object))
  end

  @spec clear_reset_password(Ecto.Changeset.t | map) :: Ecto.Changeset.t
  def clear_reset_password(changeset) do
    changeset
    |> change(%{
      reset_password_token: nil,
      reset_password_sent_at: nil,
    })
  end

  @spec prepare_reset_password(Ecto.Changeset.t | map, map) :: Ecto.Changeset.t
  def prepare_reset_password(changeset, params \\ %{}) do
    reset_password_token = params[:reset_password_token] ||
      generate_reset_password_token(changeset)
    reset_password_sent_at = params[:reset_password_sent_at] ||
      Passport.Util.generate_timestamp_for(changeset, :reset_password_sent_at)

    changeset
    |> change(%{
      reset_password_token: reset_password_token,
      reset_password_sent_at: reset_password_sent_at,
    })
  end

  def by_reset_password_token(query, token) do
    where(query, reset_password_token: ^token)
  end
end
