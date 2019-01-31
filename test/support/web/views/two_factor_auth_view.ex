defmodule Passport.Support.Web.TwoFactorAuthView do
  use Passport.Support.Web, :view

  def render("create.json", assigns) do
    Map.take(assigns[:data], [:id, :email, :username, :unconfirmed_tfa_otp_secret_key])
  end

  def render("confirm.json", assigns) do
    Map.take(assigns[:data], [:id, :email, :username, :tfa_recovery_tokens])
  end
end
