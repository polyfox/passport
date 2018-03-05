require Logger
require Passport.Repo

defmodule Passport.SessionController do
  @moduledoc """
  """
  defmacro __using__(_opts) do
    quote location: :keep do
      require Passport.Config

      @behaviour Passport.SessionController

      @impl true
      def handle_session_error(conn, err) do
        Passport.SessionController.handle_session_error(__MODULE__, conn, err)
      end

      @impl true
      def require_tfa_setup?(_conn, entity) do
        if Passport.Config.features?(entity, :two_factor_auth) do
          entity.tfa_enabled && !entity.tfa_otp_secret_key
        else
          false
        end
      end

      @doc """
      POST /login

      Params:
      * `email` - email address of the entity
      * `password` - password of the entity
      * `otp` - one-time passcode provided by the entity
      """
      def create(conn, params) do
        Passport.SessionController.create(__MODULE__, conn, params)
      end

      @doc """
      POST /logout

        Authorization: token

      Destroys the current session
      """
      def delete(conn, params) do
        Passport.SessionController.delete(__MODULE__, conn, params)
      end

      defoverridable [create: 2, delete: 2, require_tfa_setup?: 2, handle_session_error: 2]
    end
  end

  @callback require_tfa_setup?(Plug.Conn.t, term) :: boolean
  @callback handle_session_error(Plug.Conn.t, {:error, term}) :: Plug.Conn.t

  import Plug.Conn
  import Phoenix.Controller
  import Passport.APIHelper

  def handle_session_error(controller, conn, err) do
    case err do
      {:error, {:missing, :otp}} ->
        conn
        |> put_resp_header(Passport.Config.otp_header_name(), "required")
        |> send_unauthorized(reason: "Missing otp code")

      {:error, {:missing, attr}} ->
        send_parameter_missing(conn, fields: [attr])

      {:error, {:recovery_token_not_found, entity}} ->
        {:ok, _entity} = Passport.track_tfa_attempts(entity, conn.remote_ip)
        send_unauthorized(conn, reason: "Invalid Recovery Token.")

      {:error, {:missing_auth_code, entity}} ->
        {:ok, _entity} = Passport.track_tfa_attempts(entity, conn.remote_ip)
        conn
        |> put_resp_header(Passport.Config.otp_header_name(), "required")
        |> send_unauthorized(reason: "Invalid Auth code.")

      {:error, {:unauthorized_tfa, entity}} ->
        {:ok, _entity} = Passport.track_tfa_attempts(entity, conn.remote_ip)
        send_unauthorized(conn, reason: "Invalid OTP code.")

      {:error, {:unauthorized, entity}} ->
        {:ok, _entity} = Passport.track_failed_attempts(entity, conn.remote_ip)
        send_unauthorized(conn, reason: "Invalid email or password.")

      {:error, :unauthorized} ->
        # unauthorized, but no entity
        send_unauthorized(conn, reason: "Invalid email or password.")

      {:error, {:unconfirmed, entity}} ->
        send_unauthorized(conn, reason: "unconfirmed")

      {:error, {:inactive, entity}} ->
        send_unauthorized(conn, reason: "inactive")

      {:error, {:locked, entity}} ->
        conn
        |> put_resp_header("x-locked-at", DateTime.to_string(entity.locked_at))
        |> send_locked(reason: "Too many failed attempts.")

      {:error, {:missing_tfa_otp_secret_key, entity}} ->
        conn
        # Precondition required
        |> put_resp_header(Passport.Config.otp_header_name(), "required")
        |> send_precondition_required(reason: "2FA setup required.")

      {:error, {:force_tfa_setup, _entity}} ->
        conn
        # Precondition required
        |> put_resp_header(Passport.Config.otp_header_name(), "required")
        |> send_precondition_required(reason: "2FA setup required.")

      {:error, reason} ->
        Logger.error "unexpected error #{inspect(reason)}"
        send_forbidden(conn)
    end
  end

  defp try_create_session(controller, conn, entity) do
    if controller.require_tfa_setup?(conn, entity) do
      {:error, {:force_tfa_setup, entity}}
    else
      Passport.Sessions.create_session(entity)
    end
  end

  def determine_auth_code(params) do
    cond do
      params["otp"] -> {:otp, params["otp"]}
      params["recovery_token"] -> {:recovery_token, params["recovery_token"]}
      true -> nil
    end
  end

  def commit_entity_changes(%Ecto.Changeset{} = cs), do: Passport.Repo.primary().update(cs)
  def commit_entity_changes(entity), do: {:ok, entity}

  def create(controller, conn, params) do
    with {:ok, entity} <- Passport.Sessions.authenticate_entity(params["email"], params["password"], determine_auth_code(params)),
         {:ok, entity} <- commit_entity_changes(entity),
         {:ok, {token, entity}} <- try_create_session(controller, conn, entity),
         {:ok, entity} <- Passport.on_successful_sign_in(entity, conn.remote_ip) do
      conn
      |> put_status(201)
      |> render("show.json", data: entity, token: token)
    else
      {:error, _} = err -> controller.handle_session_error(conn, err)
    end
  end

  def delete(controller, %{assigns: assigns} = conn, params) do
    case Passport.Sessions.destroy_session(assigns) do
      {:ok, _session} ->
        send_no_content(conn)

      {:error, _} ->
        send_server_error(conn)
    end
  end
end
