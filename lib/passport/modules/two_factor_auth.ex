defmodule Passport.TwoFactorAuth do
  import Ecto.Changeset
  import Ecto.Query

  @type entity :: term

  defmacro schema_fields(opts \\ []) do
    quote do
      field :tfa_otp_secret_key, :string
      field :tfa_enabled, :boolean, default: false
      field :tfa_attempts_count, :integer, default: 0
      field :tfa_recovery_tokens, {:array, :string}, default: []
    end
  end

  defmacro routes(opts \\ []) do
    two_factor_auth_controller = Keyword.get(opts, :two_factor_auth_controller, TwoFactorAuthController)
    quote do
      post "/reset/tfa", unquote(two_factor_auth_controller), :create
      post "/confirm/tfa", unquote(two_factor_auth_controller), :confirm
    end
  end

  def migration_fields(_mod) do
    [
      "# TwoFactorAuth",
      "add :tfa_otp_secret_key, :string",
      "add :tfa_enabled, :boolean",
      "add :tfa_attempts_count, :integer, default: 0",
      "add :tfa_recovery_tokens, {:array, :string}, default: []",
    ]
  end

  def migration_indices(_mod) do
    # <users> will be replaced with the correct table name
    [
      ~s{create unique_index(<users>, [:tfa_otp_secret_key], where: "tfa_otp_secret_key IS NOT NULL")}
    ]
  end

  alias Passport.Keygen

  @spec generate_secret_key :: String.t
  def generate_secret_key do
    Keygen.random_string32(16)
  end

  @spec generate_tfa_recovery_token :: String.t
  def generate_tfa_recovery_token do
    Keygen.random_string16(8)
  end

  @spec generate_tfa_recovery_tokens(non_neg_integer, [String.t]) :: [String.t]
  def generate_tfa_recovery_tokens(count, acc \\ [])
  def generate_tfa_recovery_tokens(0, acc), do: acc
  def generate_tfa_recovery_tokens(count, acc) do
    generate_tfa_recovery_tokens(count - 1, [generate_tfa_recovery_token() | acc])
  end

  defp patch_tfa_otp_secret_key(changeset) do
    case get_field(changeset, :tfa_otp_secret_key) do
      nil ->
        secret = generate_secret_key()
        put_change(changeset, :tfa_otp_secret_key, secret)
      _ -> changeset
    end
  end

  defp try_clear_tfa_otp_secret_key(changeset) do
    case get_field(changeset, :tfa_enabled) do
      true -> changeset
      _ -> put_change(changeset, :tfa_otp_secret_key, nil)
    end
  end

  @doc """
  Initializes a new otp secret key for the specified account.
  """
  @spec prepare_tfa_confirmation(Ecto.Changeset.t | atom) :: Ecto.Changeset.t
  def prepare_tfa_confirmation(changeset) do
    changeset
    |> put_change(:tfa_otp_secret_key, nil)
    |> patch_tfa_otp_secret_key()
  end

  @doc """
  Initializes a new list tfa_recovery_tokens on the given entity or changeset.
  """
  @spec prepare_tfa_recovery_tokens(Ecto.Changeset.t) :: Ecto.Changeset.t
  def prepare_tfa_recovery_tokens(changeset) do
    token_count = Passport.Config.tfa_recovery_token_count(changeset)
    changeset
    |> put_change(:tfa_recovery_tokens, generate_tfa_recovery_tokens(token_count))
  end

  @spec changeset(Ecto.Changeset.t | entity, map) :: Ecto.Changeset.t
  def changeset(record, params) do
    record
    |> cast(params, [:tfa_enabled])
    |> try_clear_tfa_otp_secret_key()
    |> unique_constraint(:tfa_otp_secret_key)
  end

  @doc """
  Confirm that TFA should be enabled for the provided entity.
  """
  @spec confirm_tfa(Ecto.Changeset.t) :: Ecto.Changeset.t
  def confirm_tfa(changeset) do
    changeset
    |> put_change(:tfa_enabled, true)
    |> prepare_tfa_recovery_tokens()
  end

  @doc """
  Check the totp regardless of if tfa_enabled state
  """
  @spec abs_check_totp(entity, String.t) :: {:ok, boolean} | {:error, term}
  def abs_check_totp(record, nil) do
    {:error, {:missing, :otp}}
  end

  def abs_check_totp(record, totp) do
    case record.tfa_otp_secret_key do
      nil -> {:error, {:missing, :tfa_otp_secret_key}}
      secret -> {:ok, :pot.valid_totp(totp, secret, window: 1, addWindow: 1)}
    end
  end

  @spec check_totp(entity, String.t | nil) :: {:ok, boolean} | {:error, term}
  def check_totp(%{tfa_enabled: true} = record, totp) do
    abs_check_totp(record, totp)
  end

  def check_totp(_record, _totp) do
    {:error, :tfa_disabled}
  end

  @doc """
  Attempts to use an existing recovery token, returns a Changeset with the token removed
  """
  @spec consume_recovery_token(entity, String.t) :: {:ok, Ecto.Changeset.t} | {:error, term}
  def consume_recovery_token(entity, token) do
    if Enum.member?(entity.tfa_recovery_tokens, token) do
      changeset =
        entity
        |> change()
        |> put_change(:tfa_recovery_tokens, List.delete(entity.tfa_recovery_tokens, token))
      {:ok, changeset}
    else
      {:error, {:token_not_found, entity}}
    end
  end

  def track_tfa_attempts(changeset, _remote_ip) do
    changeset
    |> prepare_changes(fn cs ->
      id = cs.data.id
      cs.data.__struct__
      |> where(id: ^id)
      |> cs.repo.update_all(inc: [tfa_attempts_count: 1])
      cs
    end)
    # TODO: set locked_at if tfa_attempts_count exceeds a configured limit
  end

  def clear_tfa_attempts(changeset) do
    changeset
    |> put_change(:tfa_attempts_count, 0)
  end
end
