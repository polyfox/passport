defmodule Passport.Support.PasswordController do
  use Passport.Support.Web, :controller
  use Passport.PasswordController, recoverable_model: Passport.Support.User

  @impl true
  def request_reset_password(record) do
    # TODO
    {:ok, record}
  end
end
