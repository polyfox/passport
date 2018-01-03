defmodule Passport.Support.Web.SessionView do
  use Passport.Support.Web, :view

  def render("show.json", assigns) do
    %{
      data: Map.take(assigns[:data], [:id, :email, :username]),
      token: assigns[:token]
    }
  end
end
