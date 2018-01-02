defmodule Passport.Support.Web.ConfirmationView do
  use Passport.Support.Web, :view

  def render("no_content.json", _assigns), do: %{}
end
