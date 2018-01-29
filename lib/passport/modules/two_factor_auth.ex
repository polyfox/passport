defmodule Passport.TwoFactorAuth do
  import Ecto.Changeset
  import Ecto.Query

  defmacro schema_fields do
    quote do
      field :tfa_confirmation_token, :string
      field :tfa_confirmed_at, :utc_datetime
      field :tfa_otp_secret_key, :string
      field :tfa_enabled, :boolean, default: false
      field :tfa_attempts_count, :integer, default: 0
    end
  end

  defmacro routes(opts \\ []) do
    two_factor_auth_controller = Keyword.get(opts, :two_factor_auth_controller, TwoFactorAuthController)
    quote do
      post "/confirm/tfa", unquote(two_factor_auth_controller), :create
      get "/confirm/tfa/:token", unquote(two_factor_auth_controller), :show
      post "/confirm/tfa/:token", unquote(two_factor_auth_controller), :confirm
      delete "/confirm/tfa/:token", unquote(two_factor_auth_controller), :delete
    end
  end

  def migration_fields(_mod) do
    [
      "# TwoFactorAuth",
      "add :tfa_confirmation_token, :string",
      "add :tfa_confirmed_at, :utc_datetime",
      "add :tfa_otp_secret_key, :string",
      "add :tfa_enabled, :boolean",
      "add :tfa_attempts_count, :integer, default: 0",
    ]
  end

  def migration_indices(_mod) do
    # <users> will be replaced with the correct table name
    [
      "create unique_index(<users>, [:tfa_otp_secret_key])",
      "create unique_index(<users>, [:tfa_confirmation_token])",
    ]
  end

  alias Passport.Keygen

  def generate_secret_key do
    Keygen.random_string32(16)
  end

  def generate_tfa_confirmation_token do
    Keygen.random_string(128)
  end

  @doc """
  Confirm that TFA should be enabled for the provided entity.
  """
  @spec confirm_tfa(Ecto.Changeset.t) :: Ecto.Changeset.t
  def confirm_tfa(changeset) do
    changeset
    |> put_change(:tfa_confirmation_token, nil)
    |> put_change(:tfa_confirmed_at, DateTime.utc_now())
    |> put_change(:tfa_enabled, true)
  end

  def new_tfa_confirmation(changeset) do
    changeset
    |> put_change(:tfa_confirmation_token, generate_tfa_confirmation_token())
  end

  def prepare_tfa_confirmation(changeset) do
    changeset
    |> new_tfa_confirmation()
    |> put_change(:tfa_confirmed_at, nil)
    |> put_change(:tfa_enabled, false)
  end

  def cancel_tfa_confirmation(changeset) do
    changeset
    |> put_change(:tfa_confirmation_token, nil)
  end

  def by_tfa_confirmation_token(query, token) do
    where(query, tfa_confirmation_token: ^token)
  end

  defp patch_tfa_otp_secret_key(changeset) do
    case get_field(changeset, :tfa_otp_secret_key) do
      nil ->
        secret = generate_secret_key()
        put_change(changeset, :tfa_otp_secret_key, secret)
      _ -> changeset
    end
  end

  def changeset(record, params) do
    record
    |> cast(params, [:tfa_enabled])
    |> patch_tfa_otp_secret_key()
    |> unique_constraint(:tfa_otp_secret_key)
  end

  @doc """
  Check the totp regardless of if tfa_enabled state
  """
  @spec abs_check_totp(term, String.t) :: boolean
  def abs_check_totp(record, totp) do
    secret = record.tfa_otp_secret_key
    :pot.valid_totp(totp, secret, window: 1, addWindow: 1)
  end

  @spec check_totp(record :: term, totp :: String.t) :: boolean | {:error, term}
  def check_totp(_record, nil) do
    {:error, {:missing, :otp}}
  end

  def check_totp(%{tfa_enabled: true} = record, totp) do
    abs_check_totp(record, totp)
  end

  def check_totp(_record, _totp) do
    {:error, :tfa_disabled}
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
