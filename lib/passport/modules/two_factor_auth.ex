defmodule Passport.TwoFactorAuth do
  import Ecto.Changeset
  import Ecto.Query

  @type entity :: term

  defmacro schema_fields(_opts \\ []) do
    quote do
      field :unconfirmed_tfa_otp_secret_key, :string
      field :tfa_otp_secret_key,  :string
      field :tfa_enabled,         :boolean, default: false
      field :tfa_attempts_count,  :integer, default: 0
      field :tfa_recovery_tokens, {:array, :string}, default: []
    end
  end

  defmacro routes(opts \\ []) do
    two_factor_auth_controller = Keyword.get(opts, :two_factor_auth_controller, TwoFactorAuthController)
    quote do
      # create a new unconfirmed token for confirmation
      post "/reset/tfa", unquote(two_factor_auth_controller), :create
      # confirm an unconfirmed token and use it as the primary otp key
      post "/confirm/tfa", unquote(two_factor_auth_controller), :confirm
      # cancel an unconfirmed token
      post "/cancel/tfa", unquote(two_factor_auth_controller), :delete
    end
  end

  @spec migration_fields(module) :: iolist
  def migration_fields(_mod) do
    [
      "# TwoFactorAuth",
      "add :unconfirmed_tfa_otp_secret_key, :string",
      "add :tfa_otp_secret_key,             :string",
      "add :tfa_enabled,                    :boolean",
      "add :tfa_attempts_count,             :integer, default: 0",
      "add :tfa_recovery_tokens,            {:array, :string}, default: []",
    ]
  end

  @spec migration_indices(module) :: iolist
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

  @spec patch_otp_secret_key(Ecto.Changeset.t | entity, atom) :: Ecto.Changeset.t
  defp patch_otp_secret_key(changeset, key) do
    case get_field(changeset, key) do
      nil ->
        secret = generate_secret_key()
        put_change(changeset, key, secret)
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
  Initializes the entity's unconfirmed_tfa_otp_secret_key, once the tfa has been confirmed the active
  tfa_otp_secret_key will be replaced by it.
  """
  @spec prepare_tfa_confirmation(Ecto.Changeset.t | atom) :: Ecto.Changeset.t
  def prepare_tfa_confirmation(changeset) do
    changeset
    |> put_change(:unconfirmed_tfa_otp_secret_key, nil)
    |> patch_otp_secret_key(:unconfirmed_tfa_otp_secret_key)
  end

  @doc """
  Initializes a new list of tfa_recovery_tokens on the given entity or changeset.
  """
  @spec prepare_tfa_recovery_tokens(Ecto.Changeset.t) :: Ecto.Changeset.t
  def prepare_tfa_recovery_tokens(changeset) do
    token_count = Passport.Config.tfa_recovery_token_count(changeset)
    changeset
    |> put_change(:tfa_recovery_tokens, generate_tfa_recovery_tokens(token_count))
  end

  @doc """
  Clears all tfa recovery tokens
  """
  @spec destroy_tfa_recovery_tokens(Ecto.Changeset.t) :: Ecto.Changeset.t
  def destroy_tfa_recovery_tokens(changeset) do
    changeset
    |> put_change(:tfa_recovery_tokens, [])
  end

  @spec changeset(Ecto.Changeset.t | entity, map, :update) :: Ecto.Changeset.t
  def changeset(entity, params, kind \\ :update)
  def changeset(entity, _params, :initialize) do
    entity
    |> change(%{
      tfa_enabled: true,
      tfa_otp_secret_key: nil,
      unconfirmed_tfa_otp_secret_key: nil,
    })
    |> destroy_tfa_recovery_tokens()
    |> patch_otp_secret_key(:tfa_otp_secret_key)
    |> prepare_tfa_recovery_tokens()
    |> validate_required([:tfa_enabled, :tfa_otp_secret_key])
  end
  def changeset(entity, _params, :disable) do
    entity
    |> change(%{
      tfa_enabled: false,
      tfa_otp_secret_key: nil,
      unconfirmed_tfa_otp_secret_key: nil,
    })
    |> destroy_tfa_recovery_tokens()
  end
  def changeset(entity, _params, :confirm) do
    changeset = change(entity)
    changeset
    |> put_change(:tfa_enabled, true)
    |> put_change(:tfa_otp_secret_key, get_field(changeset, :unconfirmed_tfa_otp_secret_key))
    |> put_change(:unconfirmed_tfa_otp_secret_key, nil)
    |> prepare_tfa_recovery_tokens()
    |> validate_required([:tfa_otp_secret_key])
  end
  def changeset(entity, params, :update) do
    entity
    |> cast(params, [:tfa_enabled])
    |> try_clear_tfa_otp_secret_key()
    |> unique_constraint(:tfa_otp_secret_key)
  end

  @doc """
  Forcefully initialize the tfa_otp_secret_key and reset any temporary states.

  **Note** this also resets the recovery tokens.
  """
  @spec initialize_tfa(entity) :: Ecto.Changeset.t
  def initialize_tfa(entity) do
    changeset(entity, %{}, :initialize)
  end

  @doc """
  Confirm that TFA should be enabled for the provided entity.
  """
  @spec confirm_tfa(Ecto.Changeset.t | entity) :: Ecto.Changeset.t
  def confirm_tfa(entity) do
    changeset(entity, %{}, :confirm)
  end

  @doc """
  Validates given One Time Passcode against the entity.

  Specific otp secrete keys can be specified with the third parameter
  """
  @spec abs_check_totp(entity, String.t, :tfa_otp_secret_key | :unconfirmed_tfa_otp_secret_key) :: {:ok, boolean} | {:error, term}
  def abs_check_totp(_entity, totp, key \\ :tfa_otp_secret_key)
  def abs_check_totp(_entity, nil, _) do
    {:error, {:missing, :otp}}
  end
  def abs_check_totp(entity, totp, key) do
    case Map.get(entity, key) do
      nil -> {:error, {:missing, key}}
      secret -> {:ok, :pot.valid_totp(totp, secret, window: 1, addWindow: 1)}
    end
  end

  @spec check_totp(entity, String.t | nil) :: {:ok, boolean} | {:error, term}
  def check_totp(%{tfa_enabled: true} = entity, totp) do
    abs_check_totp(entity, totp, :tfa_otp_secret_key)
  end
  def check_totp(_entity, _totp) do
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
      {:error, {:recovery_token_not_found, entity}}
    end
  end

  @spec track_tfa_attempts(Ecto.Query.t | module, String.t) :: Ecto.Query.t
  def track_tfa_attempts(query, _remote_ip) do
    query
    |> update(inc: [tfa_attempts_count: 1])
  end

  @spec clear_tfa_attempts(Ecto.Changeset.t | entity) :: Ecto.Changeset.t
  def clear_tfa_attempts(changeset) do
    changeset
    |> put_change(:tfa_attempts_count, 0)
  end
end
