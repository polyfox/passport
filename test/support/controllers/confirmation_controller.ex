defmodule Passport.Support.ConfirmationController do
  use Passport.Support.Web, :controller
  use Passport.ConfirmationController, confirmable_model: Passport.Support.User
end
