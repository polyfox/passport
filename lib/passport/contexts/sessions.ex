require Passport.Repo

defmodule Passport.Sessions do
  @moduledoc """
  User sessions context, handles the creation of api session tokens.

  To configure a `sessions_client`

  ```elixir
  config :passport,
    sessions_client: MySessionsClient
  ```

  To create a sessions module do:

  ```elixir
  defmodule MySessionsClient do
    use Passport.Sessions

    @impl true
    def find_entity_by_identity(identity) do
      # You implementation here
    end

    @impl true
    def check_authentication(entity, params) do
      # You implementation here, that calls Passport.check_authenticatable at some point
    end

    @impl true
    def create_session(entity, _params) do
      token = some_token_generation
      {:ok, {token, entity}}
    end

    @impl true
    def get_session(token) do
      {:ok, keyword_list_of_data}
    end
  end
  ```
  """
  alias Passport.TwoFactorAuth
  alias Passport.Config

  defmodule Client do
    @moduledoc """
    Behaviour callbacks for implementing a Sessions Client module
    """

    @doc """
    Use to find an entity by it's identity
    """
    @callback find_entity_by_identity(identity :: String.t) :: nil | term

    @doc """
    Checks the entity's authentication status

    `params` will contain all parameters sent for the authentication such as `password`, `otp` etc...
    """
    @callback check_authentication(entity :: nil | term, params :: map) :: {:ok, term} | {:error, term}

    @doc """
    Creates a new session the function should return the session token and the entity
    """
    @callback create_session(entity :: nil | term, params :: map) :: {:ok, {token :: String.t, entity :: term}} | {:error, term}

    @doc """
    Retries an existing session, the function should return the session token and the entity
    """
    @callback get_session(token :: String.t) :: {:ok, Keyword.t} | {:error, term}

    @doc """
    Destroys a session given the conn assigns
    """
    @callback destroy_session(assigns :: map) :: {:ok, term} | {:error, term}
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Passport.Sessions.Client

      import Passport.Sessions, only: [extract_password: 1, extract_auth_code: 1]
    end
  end

  @type entity :: term

  @doc """
  Utility function for extracting passwords from given parameters
  """
  @spec extract_password(map) :: String.t | nil
  def extract_password(params) when is_map(params) do
    params["password"] || params[:password]
  end

  @spec extract_auth_code(map) :: {:otp, String.t} | {:recovery_token, String.t} | nil
  def extract_auth_code(params) when is_map(params) do
    cond do
      params[:otp] -> {:otp, params[:otp]}
      params["otp"] -> {:otp, params["otp"]}
      params[:recovery_token] -> {:recovery_token, params[:recovery_token]}
      params["recovery_token"] -> {:recovery_token, params["recovery_token"]}
      true -> nil
    end
  end

  @spec find_entity_by_identity(String.t) :: nil | term
  def find_entity_by_identity(identity) do
    sessions_client = Config.sessions_client()
    sessions_client.find_entity_by_identity(identity)
  end

  @doc """
  Authenticates the user using their identity and password ONLY.

  This should only be used for validating a password, if you wish to perform a
  full authentication, please use `authenticate_entity/2` instead
  """
  @spec basic_authenticate_entity(String.t, map) :: {:ok, entity} | {:error, term}
  def basic_authenticate_entity(identity, params) when is_map(params) do
    sessions_client = Config.sessions_client()
    identity
    |> find_entity_by_identity()
    |> sessions_client.check_authentication(params)
  end

  @spec check_auth_code(entity, {:otp, String.t} | {:recovery_token, String.t}) :: {:ok, entity} | {:error, term}
  def check_auth_code(entity, auth_code) do
    cond do
      is_nil(entity.tfa_otp_secret_key) ->
        {:error, {:missing_tfa_otp_secret_key, entity}}
      is_nil(auth_code) ->
        {:error, {:missing_auth_code, entity}}
      true ->
        case auth_code do
          {:otp, otp} ->
            case TwoFactorAuth.check_totp(entity, otp) do
              {:ok, false} -> {:error, {:unauthorized_tfa, entity}}
              {:ok, true} -> {:ok, entity}
            end
          {:recovery_token, token} ->
            TwoFactorAuth.consume_recovery_token(entity, token)
          _ ->
            {:error, {:invalid_auth_code, entity}}
        end
    end
  end

  @doc """
  Authenticates an entity without creating any new sessions, this will also handle TFA.
  """
  @spec authenticate_entity(String.t, map) :: {:ok, entity} | {:error, term}
  def authenticate_entity(identity, params \\ %{})
  def authenticate_entity(nil, _params), do: {:error, {:missing, :identity}}
  def authenticate_entity(identity, params) do
    identity
    |> basic_authenticate_entity(params)
    |> case do
      {:ok, entity} ->
        if Config.features?(entity, :two_factor_auth) && entity.tfa_enabled do
          check_auth_code(entity, extract_auth_code(params))
        else
          {:ok, entity}
        end
      {:error, _} = err -> err
    end
  end

  @doc """
  Variation of authenticate_entity specifically for TFA auth, this will force the use of an OTP code.
  """
  @spec authenticate_entity_tfa(String.t, map) :: {:ok, entity} | {:error, term}
  def authenticate_entity_tfa(identity, params \\ %{})
  def authenticate_entity_tfa(nil, _params), do: {:error, {:missing, :identity}}
  def authenticate_entity_tfa(identity, params) do
    identity
    |> basic_authenticate_entity(params)
    |> case do
      {:ok, entity} ->
        cond do
          not Config.features?(entity, :two_factor_auth) -> {:ok, entity}
          not entity.tfa_enabled -> {:ok, entity}
          not is_nil(entity.tfa_otp_secret_key) ->
            case extract_auth_code(params) do
              {:otp, code} -> check_auth_code(entity, code)
              {:recovery_token, code} ->
                {:error, {:recovery_token_obtained, entity}}
              _ ->
                {:error, {:invalid_auth_code, entity}}
            end
          true ->
            {:error, {:missing_tfa_otp_secret_key, entity}}
        end
      {:error, _} = err -> err
    end
  end

  @doc """
  Creates a new session from the given entity.
  """
  @spec create_session(term, map) :: {:ok, {token :: String.t, entity}} | {:error, term}
  def create_session(entity, params) do
    Config.sessions_client().create_session(entity, params)
  end

  @doc """
  Creates a new session and returns a corresponding token to identify it

  Args:
  * `identity` - a unique value such as a username or email to identify the entity
  * `params` - a map containing additional details, such as password, otp or extras
  """
  @spec authenticate_session(identity :: String.t, params :: map) :: {:ok, {token :: String.t, entity}} | {:error, term}
  def authenticate_session(identity, params \\ %{})
  def authenticate_session(nil, _params), do: {:error, {:missing, :identity}}
  def authenticate_session(identity, params) do
    # ident = identity/username, auth = password
    identity
    |> authenticate_entity(params)
    |> case do
      {:ok, entity} -> create_session(entity, params)
      {:error, _} = err -> err
    end
  end

  @doc """
  Retrieve a session's data by it's token

  Args:
  * `token` - the token identifying the session
  """
  @spec get_session(token :: String.t) :: {:ok, Keyword.t} | {:error, term}
  def get_session(nil), do: {:error, :no_token}
  def get_session(token) when is_binary(token) do
    sessions_client = Config.sessions_client()
    sessions_client.get_session(token)
  end
  def get_session(_), do: {:error, :invalid_token}

  @doc """
  Destroys an existing session given the conn assigns
  """
  @spec destroy_session(assigns :: map) :: {:ok, term} | {:error, term}
  def destroy_session(assigns) do
    sessions_client = Config.sessions_client()
    sessions_client.destroy_session(assigns)
  end
end
