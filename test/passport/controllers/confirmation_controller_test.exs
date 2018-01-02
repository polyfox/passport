defmodule Passport.ConfirmationControllerTest do
  use Passport.Support.Web.ConnCase

  describe "POST /account/confirm/:token" do
    test "confirms an account", %{conn: conn} do
      user = insert(:user, confirmation_token: Passport.Confirmable.generate_confirmation_token())
      assert user.confirmation_token
      conn = post conn, "/account/confirm/#{user.confirmation_token}"
      assert json_response(conn, 204)

      user = reload_user(user)
      refute user.confirmation_token
    end
  end
end
