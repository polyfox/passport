defmodule Passport.SessionController do
  @moduledoc """
  """
  defmacro __using__(_opts) do
    quote location: :keep do
      require Passport.Config

      def handle_session_error(conn, err) do
        Passport.SessionController.handle_session_error(__MODULE__, conn, err)
      end

      defoverridable [handle_session_error: 2]

      @doc """
      POST /login

      Params:
      * `email` - email address of the user
      * `password` - password of the user
      * `otp` - one-time passcode provided by the user
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

      defoverridable [create: 2, delete: 2]
    end
  end

  import Plug.Conn
  import Phoenix.Controller
  import Passport.APIHelper

  def handle_session_error(controller, conn, err) do
    case err do
      {:error, {:unauthorized_tfa, user}} ->
        {:ok, _user} = Passport.track_tfa_attempts(user, conn.remote_ip)
        send_unauthorized(conn, reason: "Invalid OTP code.")

      {:error, {:unauthorized, user}} ->
        {:ok, _user} = Passport.track_failed_attempts(user, conn.remote_ip)
        send_unauthorized(conn, reason: "Invalid email or password.")

      {:error, :unauthorized} ->
        # unauthorized, but no user
        send_unauthorized(conn, reason: "Invalid email or password.")

      {:error, {:missing, :otp}} ->
        conn
        |> put_resp_header(Passport.Config.otp_header_name(), "required")
        |> send_unauthorized(reason: "Missing otp code")

      {:error, {:missing, attr}} ->
        send_parameter_missing(conn, fields: [attr])

      {:error, :locked} ->
        send_locked(conn, reason: "Too many failed attempts.")

      {:error, _} ->
        send_forbidden(conn)
    end
  end

  def create(controller, conn, %{"email" => e, "password" => p} = params) do
    case Passport.Sessions.create(e, p, params["otp"]) do
      {:ok, {token, user}} ->
        {:ok, user} = Passport.on_successful_sign_in(user, conn.remote_ip)
        conn
        |> put_status(201)
        |> render("show.json", data: user, token: token)

      {:error, _} = err ->
        controller.handle_session_error(conn, err)
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
