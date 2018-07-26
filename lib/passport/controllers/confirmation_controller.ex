defmodule Passport.ConfirmationController do
  @moduledoc """
  Mixin for ConfirmationController, use this module in your confirmation controller and implement the callback functions.

  Example:

  ```elixir
  defmodule MyApp.Web.ConfirmationController do
    use MyApp.Web, :controller
    use Passport.ConfirmationController

    @impl true
    def confirmable_model, do: MyApp.User
  end
  ```
  """

  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Passport.ConfirmationController

      if Keyword.has_key?(unquote(opts), :confirmable_model) do
        @impl true
        def confirmable_model, do: unquote(opts[:confirmable_model])
      end

      @doc """
      POST /confirm/email
      """
      def create(conn, params) do
        Passport.ConfirmationController.create(__MODULE__, conn, params)
      end

      @doc """
      GET /confirm/email/:token
      """
      def show(conn, params) do
        Passport.ConfirmationController.show(__MODULE__, conn, params)
      end

      @doc """
      POST /confirm/email/:token

      Confirm the email for a given confirmable.

      Params:
      * `token` - the confirmable's confirmation token
      """
      def confirm(conn, params) do
        Passport.ConfirmationController.confirm(__MODULE__, conn, params)
      end

      @doc """
      DELETE /confirm/email/:token
      """
      def delete(conn, params) do
        Passport.ConfirmationController.delete(__MODULE__, conn, params)
      end
    end
  end

  @doc """
  confirmable_model denotes what module represents the Confirmable entity.

  This function should return a valid Ecto.Schema model
  """
  @callback confirmable_model() :: atom

  import Passport.APIHelper

  def create(_controller, conn, params) do
    case Passport.Sessions.find_entity_by_identity(params["email"]) do
      nil -> send_not_found(conn)
      entity ->
        case Passport.prepare_confirmation(entity) do
          {:ok, _entity} -> send_no_content(conn)
          {:error, %Ecto.Changeset{} = changeset} ->
            send_changeset_error(conn, changeset: changeset)
        end
    end
  end

  def show(controller, conn, _params) do
    case Passport.find_by_confirmation_token(controller.confirmable_model(), conn.path_params["token"]) do
      nil -> send_not_found(conn)
      confirmable -> Phoenix.Controller.render(conn, "show.json", data: confirmable)
    end
  end

  def confirm(controller, conn, _params) do
    case Passport.find_by_confirmation_token(controller.confirmable_model(), conn.path_params["token"]) do
      nil -> send_not_found(conn)
      confirmable ->
        case Passport.confirm_email(confirmable) do
          {:ok, _entity} ->
            send_no_content(conn)

          {:error, %Ecto.Changeset{} = changeset} ->
            # this should like.. never happen, but you know, shit happens
            send_changeset_error(conn, changeset: changeset)
        end
    end
  end

  def delete(controller, conn, _params) do
    case Passport.find_by_confirmation_token(controller.confirmable_model(), conn.path_params["token"]) do
      nil -> send_not_found(conn)
      confirmable ->
        case Passport.cancel_confirmation(confirmable) do
          {:ok, _entity} ->
            send_no_content(conn)

          {:error, %Ecto.Changeset{} = changeset} ->
            send_changeset_error(conn, changeset: changeset)
        end
    end
  end
end
