defmodule Passport.Confirmable do
  import Ecto.Changeset
  import Ecto.Query

  defmacro schema_fields(_options \\ []) do
    quote do
      field :confirmation_token, :string
      field :confirmed_at, :utc_datetime
      field :confirmation_sent_at, :utc_datetime
    end
  end

  defmacro routes(opts \\ []) do
    confirmable_controller = Keyword.get(opts, :confirmable_controller, ConfirmationController)
    quote do
      # Confirm user email
      post "/confirm/email", unquote(confirmable_controller), :create
      get "/confirm/email/:token", unquote(confirmable_controller), :show
      post "/confirm/email/:token", unquote(confirmable_controller), :confirm
      delete "/confirm/email/:token", unquote(confirmable_controller), :delete
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
    |> put_change(:confirmed_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def new_confirmation(changeset) do
    changeset
    |> put_change(:confirmation_token, generate_confirmation_token())
    |> put_change(:confirmation_sent_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def prepare_confirmation(changeset) do
    changeset
    |> new_confirmation()
    |> put_change(:confirmed_at, nil)
  end

  def cancel_confirmation(changeset) do
    changeset
    |> put_change(:confirmation_token, nil)
    |> put_change(:confirmation_sent_at, nil)
  end

  def by_confirmation_token(query, token) do
    where(query, confirmation_token: ^token)
  end
end
