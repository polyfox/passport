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
        case Passport.Sessions.authenticate_entity(params["email"], params["password"]) do
          {:ok, %{tfa_enabled: true} = entity} ->
            Passport.APIHelper.send_unauthorized(conn, reason: "TFA already enabled")

          {:ok, entity} ->
            case Passport.prepare_tfa_confirmation(entity) do
              {:ok, entity} ->
                conn
                |> put_status(201)
                |> render("show.json", data: entity)

              {:error, %Ecto.Changeset{} = changeset} ->
                Passport.APIHelper.send_changeset_error(conn, changeset: changeset)
            end

          {:error, {:unauthorized, _entity}} ->
            Passport.APIHelper.send_unauthorized(conn, reason: "Invalid email or password.")

          {:error, :unauthorized} ->
            # unauthorized, but no user
            Passport.APIHelper.send_unauthorized(conn, reason: "Invalid email or password.")

          {:error, {:missing, attr}} ->
            Passport.APIHelper.send_parameter_missing(conn, fields: [attr])

          {:error, :locked} ->
            Passport.APIHelper.send_locked(conn, reason: "Too many failed attempts.")

          {:error, _} ->
            Passport.APIHelper.send_forbidden(conn)
        end
      end

      @doc """
      GET /account/confirm/tfa/:token
      """
      def show(conn, params) do
        case Passport.find_by_tfa_confirmation_token(two_factor_auth_model(), params["token"]) do
          nil -> Passport.APIHelper.send_not_found(conn)
          entity -> render conn, "show.json", data: entity
        end
      end

      @doc """
      POST /account/confirm/tfa/:token
      """
      def confirm(conn, params) do
        case Passport.find_by_tfa_confirmation_token(two_factor_auth_model(), params["token"]) do
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

      @doc """
      DELETE /account/confirm/tfa/:token
      """
      def delete(conn, params) do
        case Passport.find_by_tfa_confirmation_token(two_factor_auth_model(), params["token"]) do
          nil -> Passport.APIHelper.send_not_found(conn)
          entity ->
            case Passport.cancel_tfa_confirmation(entity) do
              {:ok, _entity} -> Passport.APIHelper.send_no_content(conn)
              {:error, %Ecto.Changeset{} = changeset} ->
                Passport.APIHelper.send_changeset_error(conn, changeset: changeset)
            end
        end
      end
    end
  end

  @doc """
  two_factor_auth_model denotes what module represents the TwoFactorAuth entity.

  This function should return a valid Ecto.Schema model
  """
  @callback two_factor_auth_model() :: atom
end
