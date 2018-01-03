defmodule Passport.Support.Web.PageController do
  use Passport.Support.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def protected_content(conn, _params) do
    send_resp conn, 200, "krabby patty secret formula"
  end
end
