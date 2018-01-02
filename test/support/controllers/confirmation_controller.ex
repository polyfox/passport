defmodule Passport.Support.ConfirmationController do
  use Passport.ConfirmationController

  @impl true
  def confirmable_model, do: Passport.Support.User
end
