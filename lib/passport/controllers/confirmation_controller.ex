defmodule Passport.ConfirmationController do
  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Passport.ConfirmationController

      @doc """
      POST /confirm/:token

      Confirm the email for a given confirmable.

      Params:
      * `token` - the confirmable's confirmation token
      """
      def confirm(conn, params) do
        case Passport.find_by_confirmation_token(confirmable_model(), conn.path_params["token"]) do
          nil -> send_not_found(conn)
          confirmable ->
            case Passport.confirm_email(confirmable) do
              {:ok, _} ->
                send_no_content(conn)
              {:error, %Ecto.Changeset{} = changeset} ->
                # this should like.. never happen, but you know, shit happens
                send_changeset_error(conn, changeset)
            end
        end
      end
    end
  end

  @callback confirmable_model() :: atom
end
