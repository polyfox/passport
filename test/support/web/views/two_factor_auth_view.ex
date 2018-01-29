defmodule Passport.Support.Web.TwoFactorAuthView do
  use Passport.Support.Web, :view

  def render("show.json", assigns) do
    Map.take(assigns[:data], [:id, :email, :username, :tfa_confirmation_token])
  end
end
