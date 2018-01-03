defmodule Passport.PasswordController do
  @moduledoc """
  Controller for handling password resets

  Example:

  ```elixir
  defmodule MyApp.Web.PasswordController do
    use MyApp.Web, :view
    use Passport.PasswordController

    @impl true
    def recoverable_model, do: MyApp.User

    @impl true
    def request_reset_password(params) do
      email = params["email"]
      MyApp.User
      |> MyApp.Repo.get_by(email: email)
      |> case do
        nil -> {:error, :not_found}
        user ->
          user
          |> Passport.prepare_reset_password()
          |> MyApp.Repo.update()
      end
    end
  end
  ```
  """

  defmacro __using__(opts) do
    quote location: :keep do
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
            Passport.APIHelper.send_parameter_missing(conn, fields: [field])
          _ ->
            Passport.APIHelper.send_no_content(conn)
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
            Passport.APIHelper.send_not_found(conn, resource: "password_reset", id: token)
          authenticatable ->
            case Passport.reset_password(authenticatable, params) do
              {:ok, _authenticatable} ->
                Passport.APIHelper.send_no_content(conn)
              {:error, %Ecto.Changeset{} = changeset} ->
                Passport.APIHelper.send_changeset_error(conn, changeset: changeset)
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
            Passport.APIHelper.send_not_found(conn, resource: "password_reset", id: token)
          authenticatable ->
            case Passport.clear_reset_password(authenticatable) do
              {:ok, _authenticatable} ->
                Passport.APIHelper.send_no_content(conn)
              {:error, %Ecto.Changeset{} = changeset} ->
                # should never happen, but, things happen
                Passport.APIHelper.send_changeset_error(conn, changeset: changeset)
            end
        end
      end
    end
  end

  @callback recoverable_model() :: atom
  @callback request_reset_password(params :: map) :: {:ok, term} | {:error, term}
end
