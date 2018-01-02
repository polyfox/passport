defmodule Passport.ConfirmationController do
  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Passport.ConfirmationController

      if Keyword.has_key?(unquote(opts), :confirmable_model) do
        @impl true
        def confirmable_model, do: unquote(opts[:confirmable_model])
      end

      @doc """
      POST /confirm/:token

      Confirm the email for a given confirmable.

      Params:
      * `token` - the confirmable's confirmation token
      """
      def confirm(conn, params) do
        case Passport.find_by_confirmation_token(confirmable_model(), conn.path_params["token"]) do
          nil ->
            conn
            |> put_status(404)
            |> render("not_found.json")
          confirmable ->
            case Passport.confirm_email(confirmable) do
              {:ok, record} ->
                conn
                |> put_status(204)
                |> render("no_content.json")
              {:error, %Ecto.Changeset{} = changeset} ->
                # this should like.. never happen, but you know, shit happens
                conn
                |> put_status(422)
                |> render("error.json", changeset: changeset)
            end
        end
      end
    end
  end

  @callback confirmable_model() :: atom
end
