defmodule Passport.TwoFactorAuthController do
  defmacro __using__(opts) do
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

  def create(controller, conn, params) do
    case Passport.Sessions.authenticate_entity(params["email"], params["password"], params["otp"]) do
      {:ok, entity} ->
        case Passport.prepare_tfa_confirmation(entity) do
          {:ok, entity} ->
            conn
            |> put_status(201)
            |> render("create.json", data: entity)

          {:error, %Ecto.Changeset{} = changeset} ->
            send_changeset_error(conn, changeset: changeset)
        end

      {:error, _} = err ->
        Passport.SessionController.handle_session_error(controller, conn, err)
    end
  end

  def confirm(controller, conn, params) do
    # TFA is disabled at this point, by confirming that the otp provided this will then enable or re-enable it.
    case Passport.Sessions.authenticate_entity(params["email"], params["password"]) do
      {:ok, %{tfa_enabled: true} = entity} ->
        send_conflict(conn, reason: "TFA is already enabled")
      {:ok, entity} ->
        case Passport.TwoFactorAuth.abs_check_totp(entity, params["otp"]) do
          {:ok, false} ->
            send_unauthorized(conn, reason: "otp mismatch")
          {:ok, true} ->
            case Passport.confirm_tfa(entity) do
              {:ok, entity} ->
                render(conn, "confirm.json", data: entity)
              {:error, %Ecto.Changeset{} = changeset} ->
                send_changeset_error(conn, changeset: changeset)
            end
          {:error, _} ->
            send_parameter_missing(conn, field: :otp, reason: "otp code required")
        end
      {:error, _} = err ->
        Passport.SessionController.handle_session_error(controller, conn, err)
    end
  end
end
