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
    def check_authentication(entity, password) do
      # You implementation here, that calls Passport.check_authenticatable at some point
    end

    @impl true
    def create_session(entity) do
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
    Checks the entity's password and other auth statuses
    """
    @callback check_authentication(entity :: nil | term, password :: String.t) :: {:ok, term} | {:error, term}

    @doc """
    Creates a new session the function should return the session token and the entity
    """
    @callback create_session(entity :: nil | term) :: {:ok, {token :: String.t, entity :: term}} | {:error, term}

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
    end
  end

  @spec find_entity_by_identity(String.t) :: nil | term
  def find_entity_by_identity(identity) do
    sessions_client = Config.sessions_client()
    sessions_client.find_entity_by_identity(identity)
  end

  @doc """
  Creates a new session and returns a corresponding token to identify it

  Args:
  * `identity` - a unique value such as a username or email to identify the entity
  * `password` - a password of some kind
  """
  @spec create(identity :: String.t, password :: String.t, otp :: String.t) :: {:ok, {token :: String.t, user :: term}} | {:error, term}
  def create(identity, password, otp \\ nil)
  def create(nil, _password, _otp), do: {:error, {:missing, :identity}}
  def create(_identity, nil, _otp), do: {:error, {:missing, :password}}
  def create(identity, password, otp) do
    # ident = identity/username, auth = password
    sessions_client = Config.sessions_client()
    identity
    |> find_entity_by_identity()
    |> sessions_client.check_authentication(password)
    |> case do
      {:ok, entity} ->
        if Config.features?(entity, :two_factor_auth) && entity.tfa_enabled do
          case TwoFactorAuth.check_totp(entity, otp) do
            {:error, :tfa_disabled} -> true
            other -> other
          end
        else
          true
        end
        |> case do
          {:error, _} = err -> err
          false -> {:error, {:unauthorized_tfa, entity}}
          true -> sessions_client.create_session(entity)
        end
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
