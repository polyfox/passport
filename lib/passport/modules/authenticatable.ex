alias Passport.Config
require Config

defmodule Passport.Authenticatable do
  import Bcrypt,
    only: [verify_pass: 2, no_user_verify: 0, hash_pwd_salt: 1]

  import Ecto.Changeset

  @type entity :: term

  defmacro schema_fields(_options \\ []) do
    quote do
      field Config.password_hash_field(__MODULE__), :string
      field :old_password,          :string, virtual: true
      field :password,              :string, virtual: true
      field :password_confirmation, :string, virtual: true
      field :password_changed,      :boolean, virtual: true, default: false
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

  def migration_indices(_mod), do: []

  defp hash_password!(changeset) do
    changeset =
      changeset
      |> validate_required([:password, :password_confirmation])
      |> validate_length(:password, min: 8)
      |> validate_confirmation(:password, message: "does not match password")

    password = get_field(changeset, :password)
    if password do
      changeset
      |> put_change(:password_changed, true)
      |> put_change(Config.password_hash_field(changeset), hash_pwd_salt(password))
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

  @spec check_old_password(Ecto.Changeset.t) :: Ecto.Changeset.t
  def check_old_password(changeset) do
    case get_field(changeset, :old_password) do
      nil -> changeset
      old_password ->
        password_hash_field = Config.password_hash_field(changeset)
        password_hash = get_field(changeset, password_hash_field)
        if verify_pass(old_password, password_hash) do
          changeset
          |> hash_password!()
          |> validate_required([password_hash_field])
        else
          add_error(changeset, :old_password, "does not match old password")
        end
    end
  end

  @doc """
  Args:
  * `changeset` - the authenticable record changeset
  * `params` - the parameters to update with
  * `kind` - the changeset's kind

  Kind:
  * `:update` - updates the entity's password, the old password is required
  * `:change` - updates the entity's password, will replace the password
  * `:reset` - replaces entity's password, will fail if the password isn't set
  """
  @spec changeset(Ecto.Changeset.t, map, :update | :change | :reset) :: Ecto.Changeset.t
  def changeset(changeset, params, kind \\ :update)

  def changeset(changeset, params, :update) do
    changeset
    |> cast(params, [:old_password, :password, :password_confirmation])
    |> check_old_password()
  end

  def changeset(changeset, params, :change) do
    changeset
    |> cast(params, [:password, :password_confirmation])
    |> hash_password()
    |> validate_required([Config.password_hash_field(changeset)])
  end

  def changeset(changeset, params, :reset) do
    changeset
    |> cast(params, [:password, :password_confirmation])
    |> hash_password!()
    |> validate_required([Config.password_hash_field(changeset)])
  end

  @spec check_password(entity, String.t | nil) ::
    {:ok, entity} |
    {:error, :password_missing | :unauthorized | {:unauthorized, entity}}
  def check_password(_entity, nil) do
    no_user_verify()
    {:error, :password_missing}
  end

  def check_password(nil, _password) do
    no_user_verify()
    {:error, :unauthorized}
  end

  def check_password(entity, password) when is_binary(password) do
    case Map.fetch!(entity, Config.password_hash_field(entity)) do
      nil ->
        no_user_verify()
        {:error, {:unauthorized, entity}}
      hashed_password ->
        if verify_pass(password, hashed_password) do
          {:ok, entity}
        else
          {:error, {:unauthorized, entity}}
        end
    end
  end
end
