defmodule Passport.Support.Web.ConfirmationView do
  use Passport.Support.Web, :view

  def render("no_content.json", _assigns), do: %{}
  def render("show.json", assigns) do
    Map.take(assigns[:data], [:id, :email, :username, :confirmation_token, :confirmation_sent_at])
  end
end
