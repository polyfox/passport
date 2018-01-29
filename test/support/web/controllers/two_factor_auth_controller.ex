defmodule Passport.Support.Web.TwoFactorAuthController do
  use Passport.Support.Web, :controller
  use Passport.TwoFactorAuthController

  @impl true
  def two_factor_auth_model do
    Passport.Support.User
  end
end
