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

  def confirm_tfa(entity) do
    entity
    |> change()
    |> TwoFactorAuth.confirm_tfa()
    |> Repo.primary().update()
  end

  def entity_activated?(entity) do
    if Config.features?(entity, :activatable) do
      entity.active
    else
      true
    end
  end

  def entity_confirmed?(entity) do
    if Config.features?(entity, :confirmable) do
      !!entity.confirmed_at
    else
      true
    end
  end

  def entity_locked?(entity) do
    if Config.features?(entity, :lockable) do
      !!entity.locked_at
    else
      false
    end
  end

  @spec track_failed_attempts(term, remote_ip :: term) :: {:ok, term} | {:error, term}
  def track_failed_attempts(entity, remote_ip) do
    entity
    |> change()
    |> Lockable.track_failed_attempts(remote_ip)
    # because track_failed_attempts uses a prepare_changes, ecto believes the
    # entity has not changed and will not execute the update
    # force: true, here ensures that the prepare_changes is ran
    |> Repo.primary().update(force: true)
  end

  @spec track_tfa_attempts(term, remote_ip :: term) :: {:ok, term} | {:error, term}
  def track_tfa_attempts(entity, remote_ip) do
    entity
    |> change()
    |> TwoFactorAuth.track_tfa_attempts(remote_ip)
    # because track_failed_attempts uses a prepare_changes, ecto believes the
    # entity has not changed and will not execute the update,
    # force: true, here ensures that the prepare_changes is ran
    |> Repo.primary().update(force: true)
  end

  @spec prepare_tfa_confirmation(term) :: {:ok, term} | {:error, Ecto.Changeset.t | term}
  def prepare_tfa_confirmation(entity) do
    entity
    |> change()
    |> TwoFactorAuth.prepare_tfa_confirmation()
    |> Repo.primary().update()
  end

  @spec prepare_confirmation(term) :: {:ok, term} | {:error, Ecto.Changeset.t | term}
  def prepare_confirmation(entity) do
    entity
    |> change()
    |> Confirmable.prepare_confirmation()
    |> Repo.primary().update()
  end

  @spec cancel_confirmation(term) :: {:ok, term} | {:error, Ecto.Changeset.t | term}
  def cancel_confirmation(entity) do
    entity
    |> change()
    |> Confirmable.cancel_confirmation()
    |> Repo.primary().update()
  end

  @spec confirm_email(Ecto.Changeset.t | term) :: {:ok, term} | {:error, term}
  def confirm_email(entity) do
    entity
    |> change()
    |> Confirmable.confirm()
    |> Repo.primary().update()
  end

  @doc """
  Changeset used for password resets/changes

  Args:
  * `entity` - the user to set password for
  * `params` - the parameters
  """
  def changeset(entity, params, :password) do
    changeset = entity
    changeset = if Config.features?(entity, :authenticatable) do
      Authenticatable.changeset(changeset, params, :reset)
    else
      changeset
    end
    changeset = if Config.features?(entity, :recoverable) do
      Recoverable.clear_reset_password(changeset)
    else
      changeset
    end
  end

  @doc """
  Changeset used for updates

  Args:
  * `entity` - the user to update
  * `params` - the parameters
  """
  def changeset(entity, params) do
    changeset = entity
    changeset = if Config.features?(entity, :two_factor_auth) do
      TwoFactorAuth.changeset(changeset, params)
    else
      changeset
    end
    if Config.features?(entity, :authenticatable) do
      Authenticatable.changeset(changeset, params)
    else
      changeset
    end
  end

  @spec prepare_reset_password(Ecto.Changeset.t | Recoverable.t) :: {:ok, term} | {:error, term}
  def prepare_reset_password(entity) do
    changeset = change(entity)
    changeset = if Config.features?(entity, :recoverable) do
      Recoverable.prepare_reset_password(changeset)
    else
      changeset
    end
    Repo.primary().update(changeset)
  end

  @doc """
  Resets a user's password and clears any reset information
  """
  @spec reset_password(term, params) :: {:ok, term} | {:error, term}
  def reset_password(entity, params) do
    entity
    |> changeset(params, :password)
    |> Repo.primary().update()
  end

  @doc """
  Clears a reset password request

  Args:
  * `entity` - the user to clear
  """
  @spec clear_reset_password(term) :: {:ok, term} | {:error, term}
  def clear_reset_password(entity) do
    changeset = change(entity)
    changeset = if Config.features?(entity, :recoverable) do
      Recoverable.clear_reset_password(changeset)
    else
      changeset
    end
    Repo.primary().update(changeset)
  end

  @spec on_successful_sign_in(term, remote_ip :: term) :: {:ok, term} | {:error, term}
  def on_successful_sign_in(entity, remote_ip) do
    changeset = change(entity)
    changeset = if Config.features?(entity, :trackable) do
      # log sign in
      Trackable.track_sign_in(changeset, remote_ip)
    else
      changeset
    end
    changeset = if Config.features?(entity, :lockable) do
      # clear failed_attempts
      Lockable.clear_failed_attempts(changeset)
    else
      changeset
    end
    changeset = if Config.features?(entity, :two_factor_auth) do
      # clear tfa attempts
      TwoFactorAuth.clear_tfa_attempts(changeset)
    else
      changeset
    end
    Repo.primary().update(changeset)
  end

  @doc """
  Clears all failed login attempts for the entity.
  """
  def unlock_entity(entity) do
    changeset = change(entity)
    changeset = if Config.features?(entity, :lockable) do
      # clear failed_attempts
      changeset
      |> Lockable.clear_failed_attempts()
      |> Lockable.unlock_changeset()
    else
      changeset
    end
    Repo.primary().update(changeset)
  end

  @spec check_authenticatable(term, String.t) :: {:ok, term} | {:error, term}
  def check_authenticatable(entity, password) do
    case Authenticatable.check_password(entity, password) do
      {:ok, entity} ->
        cond do
          not entity_activated?(entity) -> {:error, :inactive}
          not entity_confirmed?(entity) -> {:error, :unconfirmed}
          entity_locked?(entity) -> {:error, :locked}
          true -> {:ok, entity}
        end

      {:error, _} = err -> err
    end
  end
end
