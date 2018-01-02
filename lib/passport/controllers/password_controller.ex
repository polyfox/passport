defmodule Passport.PasswordController do
  defmacro __using__(opts) do
    quote location: :keep do
      alias Passport

      @behaviour Passport.PasswordController

      if Keyword.has_key?(unquote(opts), :recoverable_model) do
        @impl true
        def recoverable_model, do: unquote(opts[:recoverable_model])
      end

      @doc """
      POST /password

      Requests a password reset for given email

      Params:
      * `email` - the email address associated with the user account to send the request to
      """
      def create(conn, params) do
        case request_reset_password(params) do
          {:error, {:parameter_missing, field}} ->
            conn
            |> put_status(422)
            |> render("parameter_missing.json", fields: [field])
          _ ->
            conn
            |> put_status(204)
            |> render("no_content.json")
        end
      end

      @doc """
      PUT /password/:token

      Resets a user's password given their reset password token

      Params:
      * `token` - the reset password token
      """
      def update(conn, params) do
        token = conn.path_params["token"]
        case Passport.find_by_reset_password_token(recoverable_model(), token) do
          nil ->
            conn
            |> put_status(404)
            |> render("not_found.json", resource: "password_reset", id: token)
          authenticatable ->
            case Passport.reset_password(authenticatable, params) do
              {:ok, _authenticatable} ->
                conn
                |> put_status(204)
                |> render("no_content.json")
              {:error, %Ecto.Changeset{} = changeset} ->
                conn
                |> put_status(422)
                |> render("error.json", changeset: changeset)
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
        token = conn.path_params["token"]
        case Passport.find_by_reset_password_token(recoverable_model(), token) do
          nil ->
            conn
            |> put_status(404)
            |> render("not_found.json", resource: "password_reset", id: token)
          authenticatable ->
            case Passport.clear_reset_password(authenticatable) do
              {:ok, _authenticatable} ->
                conn
                |> put_status(204)
                |> render("no_content.json")
              {:error, %Ecto.Changeset{} = changeset} ->
                # should never happen, but, things happen
                conn
                |> put_status(422)
                |> render("error.json", changeset: changeset)
            end
        end
      end
    end
  end

  @callback recoverable_model() :: atom
  @callback request_reset_password(params :: map) :: {:ok, term} | {:error, term}
end
