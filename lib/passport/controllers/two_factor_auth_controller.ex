defmodule Passport.TwoFactorAuthController do
  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Passport.TwoFactorAuthController

      require Passport.Config

      if Keyword.has_key?(unquote(opts), :two_factor_auth_model) do
        @impl true
        def two_factor_auth_model, do: unquote(opts[:two_factor_auth_model])
      end

      @doc """
      POST /account/confirm/tfa
      """
      def create(conn, params) do
        Passport.TwoFactorAuthController.create(__MODULE__, conn, params)
      end

      @doc """
      GET /account/confirm/tfa/:token
      """
      def show(conn, params) do
        Passport.TwoFactorAuthController.show(__MODULE__, conn, params)
      end

      @doc """
      POST /account/confirm/tfa/:token
      """
      def confirm(conn, params) do
        Passport.TwoFactorAuthController.confirm(__MODULE__, conn, params)
      end

      @doc """
      DELETE /account/confirm/tfa/:token
      """
      def delete(conn, params) do
        Passport.TwoFactorAuthController.delete(__MODULE__, conn, params)
      end

      defoverridable [create: 2, show: 2, confirm: 2, delete: 2]
    end
  end

  import Plug.Conn
  import Phoenix.Controller
  import Passport.APIHelper

  @doc """
  two_factor_auth_model denotes what module represents the TwoFactorAuth entity.

  This function should return a valid Ecto.Schema model
  """
  @callback two_factor_auth_model() :: atom

  def create(_controller, conn, params) do
    case Passport.Sessions.authenticate_entity(params["email"], params["password"]) do
      {:ok, %{tfa_enabled: true} = entity} ->
        send_unauthorized(conn, reason: "TFA already enabled")

      {:ok, entity} ->
        case Passport.prepare_tfa_confirmation(entity) do
          {:ok, entity} ->
            conn
            |> put_status(201)
            |> render("show.json", data: entity)

          {:error, %Ecto.Changeset{} = changeset} ->
            send_changeset_error(conn, changeset: changeset)
        end

      {:error, {:unauthorized, _entity}} ->
        send_unauthorized(conn, reason: "Invalid email or password.")

      {:error, :unauthorized} ->
        # unauthorized, but no user
        send_unauthorized(conn, reason: "Invalid email or password.")

      {:error, {:missing, attr}} ->
        send_parameter_missing(conn, fields: [attr])

      {:error, :locked} ->
        send_locked(conn, reason: "Too many failed attempts.")

      {:error, _} ->
        send_forbidden(conn)
    end
  end

  def show(controller, conn, _params) do
    case Passport.find_by_tfa_confirmation_token(controller.two_factor_auth_model(), conn.path_params["token"]) do
      nil -> send_not_found(conn)
      entity -> render conn, "show.json", data: entity
    end
  end

  def confirm(controller, conn, params) do
    case Passport.find_by_tfa_confirmation_token(controller.two_factor_auth_model(), conn.path_params["token"]) do
      nil -> Passport.APIHelper.send_not_found(conn)
      entity ->
        case Passport.TwoFactorAuth.abs_check_totp(entity, params["otp"]) do
          false ->
            Passport.APIHelper.send_unauthorized(conn, reason: "otp mismatch")
          true ->
            case Passport.confirm_tfa(entity) do
              {:ok, entity} ->
                Passport.APIHelper.send_no_content(conn)
              {:error, %Ecto.Changeset{} = changeset} ->
                Passport.APIHelper.send_changeset_error(conn, changeset: changeset)
            end
        end
    end
  end

  def delete(controller, conn, params) do
    case Passport.find_by_tfa_confirmation_token(controller.two_factor_auth_model(), conn.path_params["token"]) do
      nil -> send_not_found(conn)
      entity ->
        case Passport.cancel_tfa_confirmation(entity) do
          {:ok, _entity} -> send_no_content(conn)
          {:error, %Ecto.Changeset{} = changeset} ->
            send_changeset_error(conn, changeset: changeset)
        end
    end
  end
end
