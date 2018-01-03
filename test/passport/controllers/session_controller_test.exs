defmodule Passport.SessionControllerTest do
  use Passport.Support.Web.ConnCase

  describe "POST /account/login" do
    test "creates a new session", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/login", %{
        "email" => user.email,
        "password" => user.password
      }

      data = json_response conn, 201

      # for now we use the user's id as the token
      assert user.id == data["token"]
      assert user.id == data["data"]["id"]
      assert user.email == data["data"]["email"]
      assert user.username == data["data"]["username"]
    end
  end
end
