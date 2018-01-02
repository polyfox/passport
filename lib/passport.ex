defmodule Passport do
  alias Passport.{
    Activatable,
    Authenticatable,
    Confirmable,
    Lockable,
    Recoverable,
    Rememberable,
    Trackable,
    TwoFactorAuth,
    Repo
  }

  import Ecto.Changeset

  @type params :: map

  @feature_map %{
    activatable: Activatable,
    authenticatable: Authenticatable,
    confirmable: Confirmable,
    lockable: Lockable,
    recoverable: Recoverable,
    rememberable: Rememberable,
    trackable: Trackable,
    two_factor_auth: TwoFactorAuth
  }

  @all_schema_keys Map.keys(@feature_map)
  @all_routeable_keys [:recoverable, :confirmable]

  defmacro schema_fields(features \\ @all_schema_keys) do
    quote do
      unquote_splicing Enum.map(features, fn feature ->
        mod = Map.fetch!(@feature_map, feature)
        quote do
          require unquote(mod)
          unquote(mod).schema_fields()
        end
      end)
    end
  end

  defmacro routes(features \\ @all_routeable_keys) do
    quote do
      unquote_splicing Enum.map(features, fn feature ->
        mod = Map.fetch!(@feature_map, feature)
        quote do
          require unquote(mod)
          unquote(mod).routes()
        end
      end)
    end
  end

  @spec find_by_confirmation_token(query :: term, token :: String.t) :: nil | User.t
  def find_by_confirmation_token(query, nil), do: nil
  def find_by_confirmation_token(query, token) do
    query
    |> Confirmable.by_confirmation_token(token)
    |> Repo.one()
  end

  @spec find_by_reset_password_token(query :: term, token :: String.t) :: nil | User.t
  def find_by_reset_password_token(query, nil), do: nil
  def find_by_reset_password_token(query, token) do
    query
    |> Recoverable.by_reset_password_token(token)
    |> Repo.one()
  end

  @spec track_failed_attempts(term, remote_ip :: term) :: {:ok, term} | {:error, term}
  def track_failed_attempts(record, remote_ip) do
    record
    |> change()
    |> Lockable.track_failed_attempts(remote_ip)
    # because track_failed_attempts uses a prepare_changes, ecto believes the
    # record has not changed and will not execute the update
    # force: true, here ensures that the prepare_changes is ran
    |> Repo.update(force: true)
  end

  @spec track_tfa_attempts(term, remote_ip :: term) :: {:ok, term} | {:error, term}
  def track_tfa_attempts(record, remote_ip) do
    record
    |> change()
    |> TwoFactorAuth.track_tfa_attempts(remote_ip)
    # because track_failed_attempts uses a prepare_changes, ecto believes the
    # record has not changed and will not execute the update,
    # force: true, here ensures that the prepare_changes is ran
    |> Repo.update(force: true)
  end

  @spec confirm_email(Ecto.Changeset.t | term) :: {:ok, term} | {:error, term}
  def confirm_email(record) do
    record
    |> change()
    |> Confirmable.confirm()
    |> Repo.update()
  end

  @doc """
  Changeset used for password resets/changes

  Args:
  * `record` - the user to set password for
  * `params` - the parameters
  """
  def changeset(record, params, :password) do
    record
    |> Authenticatable.changeset(params, :reset)
    |> Recoverable.clear_reset_password()
  end

  @doc """
  Changeset used for updates

  Args:
  * `record` - the user to update
  * `params` - the parameters
  """
  def changeset(record, params) do
    record
    |> TwoFactorAuth.changeset(params)
    |> Authenticatable.changeset(params)
  end

  @spec prepare_reset_password(Ecto.Changeset.t | Recoverable.t) :: {:ok, term} | {:error, term}
  def prepare_reset_password(record) do
    record
    |> change()
    |> Recoverable.prepare_reset_password()
    |> Repo.update()
  end

  @doc """
  Resets a user's password and clears any reset information
  """
  @spec reset_password(User.t, params) :: {:ok, User.t} | {:error, term}
  def reset_password(record, params) do
    record
    |> changeset(params, :password)
    |> Repo.update()
  end

  @doc """
  Clears a reset password request

  Args:
  * `record` - the user to clear
  """
  @spec clear_reset_password(term) :: {:ok, term} | {:error, term}
  def clear_reset_password(record) do
    record
    |> change()
    |> Recoverable.clear_reset_password()
    |> Repo.update()
  end

  @spec on_successful_sign_in(User.t, remote_ip :: term) :: {:ok, User.t} | {:error, term}
  def on_successful_sign_in(record, remote_ip) do
    record
    |> change()
    # log sign in
    |> Trackable.track_sign_in(remote_ip)
    # clear failed_attempts
    |> Lockable.clear_failed_attempts()
    # clear tfa attempts
    |> TwoFactorAuth.clear_tfa_attempts()
    |> Repo.update()
  end

  def check_authenticatable(record, password) do
    case Authenticatable.check_password(record, password) do
      {:ok, record} ->
        cond do
          !record.active -> {:error, :inactive}
          !record.confirmed_at -> {:error, :unconfirmed}
          !record.approved -> {:error, :unapproved}
          record.locked_at -> {:error, :locked}
          true -> {:ok, record}
        end

      {:error, _} = err -> err
    end
  end
end
