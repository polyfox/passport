defmodule Passport.TwoFactorAuthControllerTest do
  use Passport.Support.Web.ConnCase

  describe "POST /account/confirm/tfa" do
    test "creates a tfa confirmation request", %{conn: conn} do

    end
  end

  describe "GET /account/confirm/tfa/:token" do
    test "retrieves entity information for tfa confirmation", %{conn: conn} do
    end
  end

  describe "POST /account/confirm/tfa/:token" do
    test "confirm tfa is valid", %{conn: conn} do
    end
  end

  describe "DELETE /account/confirm/tfa/:token" do
    test "cancel a tfa confirmation request", %{conn: conn} do

    end
  end
end
