require Passport

defmodule Passport.Support.Web.Router do
  use Passport.Support.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :protected do
    plug Passport.Plug.VerifyHeader, realm: "Bearer"
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Passport.Support.Web do
    pipe_through :api

    scope "/account" do
      Passport.routes(only: [:authenticatable, :two_factor_auth, :confirmable, :recoverable])
    end
  end

  scope "/", Passport.Support.Web do
    pipe_through :protected
    pipe_through :api

    get "/protected_content", PageController, :protected_content

    scope "/account" do
      Passport.routes(only: [:authenticatable], protected: true)
    end
  end
end
