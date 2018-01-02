require Passport.Repo

defmodule Passport.Support.Web.PasswordController do
  use Passport.Support.Web, :controller
  use Passport.PasswordController, recoverable_model: Passport.Support.User

  @impl true
  def request_reset_password(params) do
    email = params["email"]
    case Passport.Repo.replica().get_by!(Passport.Support.User, email: email) do
      nil ->
        {:error, :not_found}
      record ->
        Passport.prepare_reset_password(record)
    end
  end
end
