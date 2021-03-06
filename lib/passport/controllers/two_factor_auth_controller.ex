defmodule Passport.TwoFactorAuthController do
  defmacro __using__(_opts) do
    quote location: :keep do
      require Passport.Config

      @doc """
      POST /account/reset/tfa
      """
      def create(conn, params) do
        Passport.TwoFactorAuthController.create(__MODULE__, conn, params)
      end

      @doc """
      POST /account/confirm/tfa
      """
      def confirm(conn, params) do
        Passport.TwoFactorAuthController.confirm(__MODULE__, conn, params)
      end

      defoverridable [create: 2, confirm: 2]
    end
  end

  import Plug.Conn
  import Phoenix.Controller
  import Passport.APIHelper
  import Passport.SessionController, only: [handle_session_error: 3]

  defp do_create(conn, entity) do
    case Passport.prepare_tfa_confirmation(entity) do
      {:ok, entity} ->
        conn
        |> put_status(201)
        |> render("create.json", data: entity)

      {:error, %Ecto.Changeset{} = changeset} ->
        send_changeset_error(conn, changeset: changeset)
    end
  end

  def create(controller, conn, params) do
    case Passport.Sessions.authenticate_entity(params["email"], params) do
      {:ok, entity} -> do_create(conn, entity)
      {:error, {:missing_tfa_otp_secret_key, entity}} -> do_create(conn, entity)
      {:error, _} = err ->
        handle_session_error(controller, conn, err)
    end
  end

  def do_confirm(controller, conn, entity, params) do
    case Passport.TwoFactorAuth.abs_check_totp(entity, params["otp"], :unconfirmed_tfa_otp_secret_key) do
      {:ok, true} ->
        case Passport.confirm_tfa(entity) do
          {:ok, entity} ->
            render(conn, "confirm.json", data: entity)
          {:error, %Ecto.Changeset{} = changeset} ->
            send_changeset_error(conn, changeset: changeset)
        end

      {:ok, false} ->
        send_unauthorized(conn, reason: "incorrect otp code")

      {:error, {:missing, :otp}} ->
        send_precondition_required(conn, reason: "no otp confirmation in progress")

      {:error, _} = err ->
        handle_session_error(controller, conn, err)
    end
  end

  @spec confirm(module, Plug.Conn.t, map) :: Plug.Conn.t
  def confirm(controller, conn, params) do
    case Passport.Sessions.authenticate_entity_tfa(params["email"], params) do
      {:ok, entity} ->
        do_confirm(controller, conn, entity, params)
      {:error, {:missing_tfa_otp_secret_key, entity}} ->
        do_confirm(controller, conn, entity, params)
      {:error, _} = err ->
        handle_session_error(controller, conn, err)
    end
  end
end
