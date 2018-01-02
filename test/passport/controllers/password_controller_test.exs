defmodule Passport.PasswordControllerTest do
  use Passport.Support.Web.ConnCase

  def reload_user(user) do
    Passport.Repo.replica().get(Passport.Support.User, user.id)
  end

  describe "POST /account/password" do
    test "request a reset password", %{conn: conn} do
      user = insert(:user)
      refute user.reset_password_token
      conn = post conn, "/account/password", %{
        "email" => user.email
      }

      assert json_response(conn, 204)

      user = reload_user(user)
      assert user.reset_password_token
    end
  end

  describe "PUT /account/password/:token" do
  end

  describe "DELETE /account/password/:token" do
    test "cancels a reset password request", %{conn: conn}  do
      user = insert(:user, reset_password_token: Passport.Recoverable.generate_reset_password_token())
      assert user.reset_password_token

      conn = delete conn, "/account/password/#{user.reset_password_token}"
      assert json_response(conn, 204)

      user = reload_user(user)
      refute user.reset_password_token
    end
  end
end
