defmodule Passport.Auth.PasswordController do
  defmacro __using__(_opts) do
    quote location: :keep do
      alias Passport.Auth

      @behaviour Passport.Auth.PasswordController

      @doc """
      POST /password

      Requests a password reset for given email

      Params:
      * `email` - the email address associated with the user account to send the request to
      """
      def create(conn, params) do
        case request_reset_password(params) do
          {:error, {:parameter_missing, field}} ->
            send_parameter_error(conn, field, :missing)
          _ -> send_no_content(conn)
        end
      end

      @doc """
      PUT /password/:token

      Resets a user's password given their reset password token

      Params:
      * `token` - the reset password token
      """
      def update(conn, params) do
        case Auth.find_by_reset_password_token(recoverable_model(), conn.path_params["token"]) do
          nil -> send_not_found(conn)
          authenticatable ->
            case Auth.reset_password(authenticatable, params) do
              {:ok, _authenticatable} ->
                send_no_content(conn)
              {:error, %Ecto.Changeset{} = changeset} ->
                send_changeset_error(conn, changeset)
            end
        end
      end

      @doc """
      DELETE /password/:token

      Clears a password reset request given the reset password token

      Params:
      * `token` - the reset password token
      """
      def delete(conn, _params) do
        case Auth.find_by_reset_password_token(recoverable_model(), conn.path_params["token"]) do
          nil -> send_not_found(conn)
          authenticatable ->
            case Auth.clear_reset_password(authenticatable) do
              {:ok, _authenticatable} ->
                send_no_content(conn)
              {:error, %Ecto.Changeset{} = changeset} ->
                # should never happen, but, things happen
                send_changeset_error(conn, changeset)
            end
        end
      end
    end
  end

  @callback recoverable_model() :: atom
  @callback request_reset_password(params :: map) :: {:ok, term} | {:error, term}
end
