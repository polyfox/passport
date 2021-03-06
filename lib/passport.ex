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
  import Ecto.Query

  @type params :: map
  @type entity :: term

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

  defp apply_only_and_except_filters(keys, options) do
    cond do
      Keyword.has_key?(options, :only) ->
        Enum.filter(keys, &Enum.member?(options[:only], &1))
      Keyword.has_key?(options, :except) ->
        Enum.reject(keys, &Enum.member?(options[:except], &1))
      true -> keys
    end
  end

  defmacro schema(options \\ []) do
    features = apply_only_and_except_filters(@all_schema_keys, options)
    quote location: :keep do
      @passport_enabled_features unquote(features)

      defmacro passport_enabled_features do
        @passport_enabled_features
      end

      @doc """
      Is the specified passport feature available?
      """
      @spec passport_feature?(atom) :: boolean
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

  defmacro schema_fields(options \\ []) do
    features = apply_only_and_except_filters(@all_schema_keys, options)
    quote do
      unquote_splicing Enum.map(features, fn feature ->
        mod = Map.fetch!(@feature_map, feature)
        quote do
          unquote(mod).schema_fields(unquote(options))
        end
      end)
    end
  end

  defmacro routes(options \\ []) do
    features = apply_only_and_except_filters(@all_schema_keys, options)
    quote do
      unquote_splicing Enum.map(features, fn feature ->
        mod = Map.fetch!(@feature_map, feature)
        quote do
          require unquote(mod)
          unquote(mod).routes(unquote(options))
        end
      end)
    end
  end

  @spec migration_fields(String.t | atom) :: iolist
  def migration_fields(user_mod) when is_atom(user_mod) or is_binary(user_mod) do
    @feature_map
    |> Enum.map(fn {_, mod} ->
      mod.migration_fields(user_mod)
    end)
    |> List.flatten()
  end

  @spec migration_indices(String.t | atom) :: iolist
  def migration_indices(user_mod) when is_atom(user_mod) or is_binary(user_mod) do
    @feature_map
    |> Enum.map(fn {_, mod} ->
      mod.migration_indices(user_mod)
    end)
    |> List.flatten()
  end

  @spec find_by_confirmation_token(query :: Ecto.Query.t | module, token :: String.t) :: nil | term
  def find_by_confirmation_token(_query, nil), do: nil
  def find_by_confirmation_token(query, token) do
    query
    |> Confirmable.by_confirmation_token(token)
    |> Repo.replica().one()
  end

  @spec find_by_reset_password_token(query :: Ecto.Query.t | module, token :: String.t) :: nil | term
  def find_by_reset_password_token(_query, nil), do: nil
  def find_by_reset_password_token(query, token) do
    query
    |> Recoverable.by_reset_password_token(token)
    |> Repo.replica().one()
  end

  @doc """
  Generates the tfa_otp_secret_key and clears any temporary states.
  """
  @spec initialize_tfa(entity) :: {:ok, entity} | {:error, term}
  def initialize_tfa(entity) do
    entity
    |> change()
    |> TwoFactorAuth.initialize_tfa()
    |> Repo.primary().update()
  end

  @spec confirm_tfa(entity) :: {:ok, entity} | {:error, term}
  def confirm_tfa(entity) do
    entity
    |> change()
    |> TwoFactorAuth.confirm_tfa()
    |> Repo.primary().update()
  end

  @spec entity_activated?(term) :: boolean
  def entity_activated?(entity) do
    if Config.features?(entity, :activatable) do
      Activatable.activated?(entity)
    else
      true
    end
  end

  @spec entity_confirmed?(term) :: boolean
  def entity_confirmed?(entity) do
    if Config.features?(entity, :confirmable) do
      Confirmable.confirmed?(entity)
    else
      true
    end
  end

  @spec entity_locked?(term) :: boolean
  def entity_locked?(entity) do
    if Config.features?(entity, :lockable) do
      Lockable.locked?(entity)
    else
      false
    end
  end

  @spec track_failed_attempts(entity, remote_ip :: term) :: {:ok, entity} | {:error, term}
  def track_failed_attempts(entity, remote_ip) do
    if Config.features?(entity, :lockable) do
      Repo.primary().transaction(fn ->
        entity_id = entity.id

        scope =
          entity.__struct__
          |> where(id: ^entity_id)

        {1, [failed_attempts]} =
          scope
          |> select([e], e.failed_attempts)
          |> Lockable.track_failed_attempts(remote_ip)
          |> Repo.primary().update_all([])

        {1, [entity]} =
          scope
          |> select([e], e)
          |> Lockable.try_lock(failed_attempts, :authenticate)
          |> case do
            {true, query} ->
              Repo.primary().update_all(query, [])

            {false, _} ->
              {1, [Repo.primary().one(scope)]}
          end

        entity
      end)
    else
      {:ok, entity}
    end
  end

  @spec track_tfa_attempts(entity, remote_ip :: term) :: {:ok, entity} | {:error, term}
  def track_tfa_attempts(entity, remote_ip) do
    if Config.features?(entity, :two_factor_auth) do
      Repo.primary().transaction(fn ->
        entity_id = entity.id

        scope =
          entity.__struct__
          |> where(id: ^entity_id)

        {1, [tfa_attempts_count]} =
          scope
          |> select([e], e.tfa_attempts_count)
          |> TwoFactorAuth.track_tfa_attempts(remote_ip)
          |> Repo.primary().update_all([])

        {1, [entity]} =
          scope
          |> select([e], e)
          |> Lockable.try_lock(tfa_attempts_count, :tfa)
          |> case do
            {true, query} ->
              Repo.primary().update_all(query, [])

            {false, _} ->
              {1, [Repo.primary().one(scope)]}
          end

        entity
      end)
    else
      {:ok, entity}
    end
  end

  @spec prepare_tfa_confirmation(entity) :: {:ok, term} | {:error, Ecto.Changeset.t | term}
  def prepare_tfa_confirmation(entity) do
    entity
    |> change()
    |> TwoFactorAuth.prepare_tfa_confirmation()
    |> Repo.primary().update()
  end

  @spec prepare_confirmation(entity, map) :: {:ok, term} | {:error, Ecto.Changeset.t | term}
  def prepare_confirmation(entity, params \\ %{}) do
    entity
    |> change()
    |> Confirmable.prepare_confirmation(params)
    |> Repo.primary().update()
  end

  @spec cancel_confirmation(entity) :: {:ok, term} | {:error, Ecto.Changeset.t | term}
  def cancel_confirmation(entity) do
    entity
    |> change()
    |> Confirmable.cancel_confirmation()
    |> Repo.primary().update()
  end

  @spec confirm_email(Ecto.Changeset.t | entity, map) :: {:ok, term} | {:error, term}
  def confirm_email(entity, params \\ %{}) do
    entity
    |> change()
    |> Confirmable.confirm(params)
    |> Repo.primary().update()
  end

  @doc """
  Args:
  * `entity` - the user to set password for
  * `params` - the parameters
  * `kind` - the kind of changes to apply
  """
  @spec changeset(entity :: entity, params :: map, :activation | :password_update | :password_reset | :password_change | :update) :: Ecto.Changeset.t
  def changeset(entity, params, kind \\ :update)

  def changeset(entity, params, :activation) do
    changeset = entity
    if Config.features?(entity, :activatable) do
      Activatable.changeset(changeset, params)
    else
      changeset
    end
  end

  def changeset(entity, params, :password_reset) do
    changeset = if Config.features?(entity, :authenticatable) do
      Authenticatable.changeset(entity, params, :reset)
    else
      entity
    end
    changeset = if Config.features?(entity, :recoverable) do
      Recoverable.clear_reset_password(changeset)
    else
      changeset
    end
    changeset
  end

  def changeset(entity, params, :password_change) do
    if Config.features?(entity, :authenticatable) do
      Authenticatable.changeset(entity, params, :change)
    else
      entity
    end
  end

  def changeset(entity, params, :password_update) do
    if Config.features?(entity, :authenticatable) do
      Authenticatable.changeset(entity, params, :update)
    else
      entity
    end
  end

  def changeset(entity, params, :update) do
    if Config.features?(entity, :two_factor_auth) do
      TwoFactorAuth.changeset(entity, params, :update)
    else
      entity
    end
    |> changeset(params, :password_update)
  end

  @spec prepare_reset_password(Ecto.Changeset.t | entity) :: {:ok, term} | {:error, term}
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
  @spec reset_password(entity, params) :: {:ok, entity} | {:error, term}
  def reset_password(entity, params) do
    changeset = changeset(entity, params, :password_reset)
    # https://github.com/polyfox/passport/issues/11
    if Config.features?(entity, :confirmable) do
      Confirmable.confirm(changeset, params)
    else
      changeset
    end
    |> Repo.primary().update()
  end

  @doc """
  Attempts to change the entity's password from the old password.

  The old password must be supplied in order to change it.

  This should be used for entitys updating their own password.

  Params:
  * `entity` - the target resource that should have it's password changed
  * `params` - the map of parameters

  Allowed Fields in Params:
  * `old_password` - the original password
  * `password` - the new password
  * `password_confirmation` - the new password's confirmation
  """
  @spec update_password(entity, params) :: {:ok, entity} | {:error, term}
  def update_password(entity, params) do
    entity
    |> changeset(params, :password_update)
    |> Repo.primary().update()
  end

  @doc """
  Attempts to change the entity's password, this will ignore the old password and replaace it.

  This should be used for admins changing an entity's password.

  Params:
  * `entity` - the target resource that should have it's password changed
  * `params` - the map of parameters

  Allowed Fields in Params:
  * `password` - the new password
  * `password_confirmation` - the new password's confirmation
  """
  @spec change_password(entity, params) :: {:ok, entity} | {:error, term}
  def change_password(entity, params) do
    entity
    |> changeset(params, :password_change)
    |> Repo.primary().update()
  end

  @doc """
  Clears a reset password request

  Args:
  * `entity` - the user to clear
  """
  @spec clear_reset_password(entity) :: {:ok, entity} | {:error, term}
  def clear_reset_password(entity) do
    if Config.features?(entity, :recoverable) do
      Recoverable.clear_reset_password(entity)
    else
      entity
    end
    |> Repo.primary().update()
  end

  @spec on_successful_sign_in(entity, remote_ip :: term) :: {:ok, entity} | {:error, term}
  def on_successful_sign_in(entity, remote_ip) do
    changeset = change(entity)
    changeset =
      if Config.features?(entity, :trackable) do
        # log sign in
        Trackable.track_sign_in(changeset, remote_ip)
      else
        changeset
      end

    changeset =
      if Config.features?(entity, :lockable) do
        # clear failed_attempts
        Lockable.clear_failed_attempts(changeset)
      else
        changeset
      end

    changeset =
      if Config.features?(entity, :two_factor_auth) do
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
  @spec unlock_entity(entity) :: {:ok, entity} | {:error, term}
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

  @spec check_authenticatable(entity, String.t) :: {:ok, entity} | {:error, term}
  def check_authenticatable(entity, password) do
    case Authenticatable.check_password(entity, password) do
      {:ok, entity} ->
        cond do
          not entity_activated?(entity) -> {:error, {:inactive, entity}}
          not entity_confirmed?(entity) -> {:error, {:unconfirmed, entity}}
          entity_locked?(entity) -> {:error, {:locked, entity}}
          true -> {:ok, entity}
        end

      {:error, _} = err -> err
    end
  end

  defdelegate authenticate_entity(identity, params), to: Passport.Sessions
end
