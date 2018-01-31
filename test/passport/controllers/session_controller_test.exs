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

    test "cannot create new session if email is incorrect", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/login", %{
        "email" => "otheremail@example.com",
        "password" => user.password
      }

      data = json_response(conn, 401)

      assert data["errors"]

      assert [
        %{"code" => "unauthorized", "detail" => "Invalid email or password.", "status" => "401", "title" => "Unauthorized"}
      ] == data["errors"]
    end

    test "cannot create new session if password is incorrect", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/login", %{
        "email" => user.email,
        "password" => "nonsense"
      }

      data = json_response(conn, 401)

      assert data["errors"]
      assert [%{"code" => "unauthorized", "detail" => "Invalid email or password.", "status" => "401", "title" => "Unauthorized"}] == data["errors"]
    end

    test "will error if the account is locked", %{conn: conn} do
      user = insert(:user, locked_at: DateTime.utc_now())
      conn = post conn, "/account/login", %{
        "email" => user.email,
        "password" => user.password
      }

      data = json_response(conn, 423)

      assert data["errors"]
      assert [
        %{"code" => "locked", "detail" => "Too many failed attempts.", "status" => "423", "title" => "Locked"}
      ] == data["errors"]
    end
  end

  describe "DELETE /account/login" do
    test "deletes a session", %{conn: conn} do
      user = insert(:user)
      conn = put_req_header(conn, "authorization", "Bearer #{user.id}")
      conn = delete conn, "/account/login"

      response(conn, 204)
    end
  end
end
