defmodule Passport.Support.Web.PageController do
  use Passport.Support.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
