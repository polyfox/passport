require Passport.Repo

defmodule Passport do
  alias Passport.{
    Config,
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

  defmacro schema(features \\ @all_schema_keys) do
    quote location: :keep do
      @passport_enabled_features unquote(features)

      defmacro passport_enabled_features do
        @passport_enabled_features
      end

      def passport_feature?(feature) do
        Enum.member?(passport_enabled_features(), feature)
      end

      unquote_splicing Enum.map(features, fn feature ->
        mod = Map.fetch!(@feature_map, feature)
        quote do
          require unquote(mod)
        end
      end)
    end
  end

  defmacro schema_fields(features \\ @all_schema_keys) do
    quote do
      unquote_splicing Enum.map(features, fn feature ->
        mod = Map.fetch!(@feature_map, feature)
        quote do
          unquote(mod).schema_fields()
        end
      end)
    end
  end

  defmacro routes(features \\ @all_routeable_keys, opts \\ []) do
    quote do
      unquote_splicing Enum.map(features, fn feature ->
        mod = Map.fetch!(@feature_map, feature)
        quote do
          require unquote(mod)
          unquote(mod).routes(unquote(opts))
        end
      end)
    end
  end

  def migration_fields(user_mod) do
    @feature_map
    |> Enum.map(fn {_, mod} ->
      mod.migration_fields(user_mod)
    end)
    |> List.flatten()
  end

  def migration_indices(user_mod) do
    @feature_map
    |> Enum.map(fn {_, mod} ->
      mod.migration_indices(user_mod)
    end)
    |> List.flatten()
  end

  @spec find_by_confirmation_token(query :: term, token :: String.t) :: nil | term
  def find_by_confirmation_token(query, nil), do: nil
  def find_by_confirmation_token(query, token) do
    query
    |> Confirmable.by_confirmation_token(token)
    |> Repo.replica().one()
  end

  @spec find_by_reset_password_token(query :: term, token :: String.t) :: nil | term
  def find_by_reset_password_token(query, nil), do: nil
  def find_by_reset_password_token(query, token) do
    query
    |> Recoverable.by_reset_password_token(token)
    |> Repo.replica().one()
  end

  @spec track_failed_attempts(term, remote_ip :: term) :: {:ok, term} | {:error, term}
  def track_failed_attempts(record, remote_ip) do
    record
    |> change()
    |> Lockable.track_failed_attempts(remote_ip)
    # because track_failed_attempts uses a prepare_changes, ecto believes the
    # record has not changed and will not execute the update
    # force: true, here ensures that the prepare_changes is ran
    |> Repo.primary().update(force: true)
  end

  @spec track_tfa_attempts(term, remote_ip :: term) :: {:ok, term} | {:error, term}
  def track_tfa_attempts(record, remote_ip) do
    record
    |> change()
    |> TwoFactorAuth.track_tfa_attempts(remote_ip)
    # because track_failed_attempts uses a prepare_changes, ecto believes the
    # record has not changed and will not execute the update,
    # force: true, here ensures that the prepare_changes is ran
    |> Repo.primary().update(force: true)
  end

  @spec confirm_email(Ecto.Changeset.t | term) :: {:ok, term} | {:error, term}
  def confirm_email(record) do
    record
    |> change()
    |> Confirmable.confirm()
    |> Repo.primary().update()
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
    |> Repo.primary().update()
  end

  @doc """
  Resets a user's password and clears any reset information
  """
  @spec reset_password(term, params) :: {:ok, term} | {:error, term}
  def reset_password(record, params) do
    record
    |> changeset(params, :password)
    |> Repo.primary().update()
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
    |> Repo.primary().update()
  end

  @spec on_successful_sign_in(term, remote_ip :: term) :: {:ok, term} | {:error, term}
  def on_successful_sign_in(record, remote_ip) do
    record
    |> change()
    # log sign in
    |> Trackable.track_sign_in(remote_ip)
    # clear failed_attempts
    |> Lockable.clear_failed_attempts()
    # clear tfa attempts
    |> TwoFactorAuth.clear_tfa_attempts()
    |> Repo.primary().update()
  end

  def entity_activated?(record) do
    if Config.features?(record, :activatable) do
      record.active
    else
      true
    end
  end

  def entity_confirmed?(record) do
    if Config.features?(record, :confirmable) do
      !!record.confirmed_at
    else
      true
    end
  end

  def entity_locked?(record) do
    if Config.features?(record, :lockable) do
      !!record.locked_at
    else
      false
    end
  end

  @spec check_authenticatable(term, String.t) :: {:ok, term} | {:error, term}
  def check_authenticatable(record, password) do
    case Authenticatable.check_password(record, password) do
      {:ok, record} ->
        cond do
          not entity_activated?(record) -> {:error, :inactive}
          not entity_confirmed?(record) -> {:error, :unconfirmed}
          entity_locked?(record) -> {:error, :locked}
          true -> {:ok, record}
        end

      {:error, _} = err -> err
    end
  end
end
