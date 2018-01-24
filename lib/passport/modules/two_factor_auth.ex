defmodule Passport.TwoFactorAuth do
  import Ecto.Changeset
  import Ecto.Query

  defmacro schema_fields do
    quote do
      field :tfa_otp_secret_key, :string
      field :tfa_enabled, :boolean, default: false
      field :tfa_attempts_count, :integer, default: 0
    end
  end

  defmacro routes(_opts \\ []) do
    quote do
    end
  end

  def migration_fields(_mod) do
    [
      "# TwoFactorAuth",
      "add :tfa_otp_secret_key, :string",
      "add :tfa_enabled, :boolean",
      "add :tfa_attempts_count, :integer, default: 0",
    ]
  end

  def migration_indices(_mod) do
    # <users> will be replaced with the correct table name
    [
      "create unique_index(<users>, [:tfa_otp_secret_key])"
    ]
  end

  alias Passport.Keygen

  def generate_secret_key do
    Keygen.random_string32(16)
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
