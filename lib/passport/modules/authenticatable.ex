alias Passport.Config
require Config

defmodule Passport.Authenticatable do
  import Comeonin.Bcrypt,
    only: [checkpw: 2, dummy_checkpw: 0, hashpwsalt: 1]

  import Ecto.Changeset

  defmacro schema_fields(_options \\ []) do
    quote do
      field Config.password_hash_field(__MODULE__), :string
      field :old_password, :string, virtual: true
      field :password, :string, virtual: true
      field :password_confirmation, :string, virtual: true
      field :password_changed, :boolean, virtual: true
    end
  end

  defmacro routes(opts \\ []) do
    authenticatable_controller = Keyword.get(opts, :authenticatable_controller, SessionController)
    if opts[:protected] do
      quote do
        delete "/login", unquote(authenticatable_controller), :delete
        post "/logout", unquote(authenticatable_controller), :delete
      end
    else
      quote do
        post "/login", unquote(authenticatable_controller), :create
      end
    end
  end

  def migration_fields(mod) do
    [
      "# Authenticatable",
      "add :#{Config.password_hash_field(mod)}, :string, null: false",
    ]
  end

  def migration_indices(mod), do: []

  defp hash_password!(changeset) do
    changeset =
      changeset
      |> validate_required([:password, :password_confirmation])
      |> validate_length(:password, min: 8)
      |> validate_confirmation(:password, message: "does not match password")

    password = get_change(changeset, :password)
    if password do
      changeset
      |> put_change(:password_changed, true)
      |> put_change(Config.password_hash_field(changeset), hashpwsalt(password))
    else
      changeset
    end
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      _password -> hash_password!(changeset)
    end
  end

  def check_old_password(changeset) do
    old_password = get_field(changeset, :old_password)
    if checkpw(old_password, get_field(changeset, Config.password_hash_field(changeset))) do
      changeset
    else
      add_error(changeset, :password, "old password does not match")
    end
  end

  @spec changeset(Ecto.Changeset.t, map, :update | :reset) :: Ecto.Changeset.t
  def changeset(changeset, params, kind \\ :update)

  def changeset(changeset, params, :update) do
    changeset
    |> cast(params, [:password, :password_confirmation])
    |> hash_password()
    |> validate_required([Config.password_hash_field(changeset)])
  end

  def changeset(changeset, params, :change) do
    changeset
    |> cast(params, [:old_password, :password, :password_confirmation])
    |> check_old_password()
    |> hash_password()
    |> validate_required([Config.password_hash_field(changeset)])
  end

  @doc """
  This variant of the authenticatable changeset is used for password resets

  It will force the user to change the password, instead of just optionally passing it.

  Args:
  * `changeset` - the authenticable record changeset
  * `params` - the parameters to update with
  """
  def changeset(changeset, params, :reset) do
    changeset
    |> cast(params, [:password, :password_confirmation])
    |> hash_password!()
    |> validate_required([Config.password_hash_field(changeset)])
  end

  def check_password(_user, nil) do
    dummy_checkpw()
    {:error, :password_missing}
  end

  def check_password(nil, _password) do
    dummy_checkpw()
    {:error, :unauthorized}
  end

  def check_password(record, password) do
    if checkpw(password, Map.get(record, Config.password_hash_field(record))) do
      {:ok, record}
    else
      {:error, {:unauthorized, record}}
    end
  end
end
