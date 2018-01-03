defmodule Passport.SessionController do
  @moduledoc """
  """
  defmacro __using__(opts) do
    quote location: :keep do
      @doc """
      POST /login

      Params:
      * `email` - email address of the user
      * `password` - password of the user
      * `otp` - one-time passcode provided by the user
      """
      def create(conn, %{"email" => e, "password" => p} = params) do
        case Passport.Sessions.create(e, p, params["otp"]) do
          {:ok, {token, user}} ->
            {:ok, user} = Passport.on_successful_sign_in(user, conn.remote_ip)
            conn
            |> put_status(201)
            |> render("show.json", data: user, token: token)

          {:error, {:unauthorized_tfa, user}} ->
            {:ok, _user} = Passport.track_tfa_attempts(user, conn.remote_ip)
            Passport.APIHelper.send_unauthorized(conn, reason: "Invalid OTP code.")

          {:error, {:unauthorized, user}} ->
            {:ok, _user} = Passport.track_failed_attempts(user, conn.remote_ip)
            Passport.APIHelper.send_unauthorized(conn, reason: "Invalid email or password.")

          {:error, :unauthorized} ->
            # unauthorized, but no user
            Passport.APIHelper.send_unauthorized(conn, reason: "Invalid email or password.")

          {:error, {:missing, :otp}} ->
            conn
            |> put_resp_header(Config.otp_header_name(), "required")
            |> Passport.APIHelper.send_unauthorized(reason: "Missing otp code")

          {:error, {:missing, attr}} ->
            Passport.APIHelper.send_parameter_missing(conn, fields: [attr])

          {:error, :locked} ->
            Passport.APIHelper.send_locked(conn, reason: "Too many failed attempts.")

          {:error, _} ->
            Passport.APIHelper.send_forbidden(conn)
        end
      end
      # TODO: add catch-all create action, or just handle it in the above

      @doc """
      POST /logout

        Authorization: token

      Destroys the current session
      """
      def delete(%{assigns: assigns} = conn, _params) do
        case Passport.Sessions.destroy_session(assigns) do
          {:ok, _session} ->
            Passport.APIHelper.send_no_content(conn)

          {:error, _} ->
            Passport.APIHelper.send_server_error(conn)
        end
      end

      @doc """
      POST /logout
        Authorization: api.token

      Destroys the session regardless
      """
      def delete(conn, _params) do
        Passport.APIHelper.send_no_content(conn)
      end
    end
  end
end
