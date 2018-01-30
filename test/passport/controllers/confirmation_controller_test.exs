defmodule Passport.ConfirmationControllerTest do
  use Passport.Support.Web.ConnCase

  describe "POST /account/confirm" do
    test "prepares a confirmation unless it was alreay confirmed", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/confirm/email", %{
        "email" => user.email
      }

      assert user = reload_user(user)

      assert user.confirmation_token
      assert user.confirmation_sent_at
    end
  end

  describe "GET /account/confirm/email/:token" do
    test "retrieve some entity information by it's confirmation token", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.prepare_confirmation(user)
      conn = get conn, "/account/confirm/email/#{user.confirmation_token}"

      data = json_response(conn, 200)

      assert %{
        "id" => user.id,
        "confirmation_sent_at" => DateTime.to_iso8601(user.confirmation_sent_at),
        "email" => user.email,
        "username" => user.username,
        "confirmation_token" => user.confirmation_token
      } == data
    end
  end

  describe "POST /account/confirm/email/:token" do
    test "confirms an account", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.prepare_confirmation(user)
      conn = post conn, "/account/confirm/email/#{user.confirmation_token}"
      assert json_response(conn, 204)

      user = reload_user(user)
      refute user.confirmation_token
    end
  end

  describe "DELETE /account/confirm/email/:token" do
    test "cancels an existing confirmation request", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.prepare_confirmation(user)
      conn = delete conn, "/account/confirm/email/#{user.confirmation_token}"

      user = reload_user(user)
      refute user.confirmation_token
      refute user.confirmation_sent_at
      refute user.confirmed_at
    end
  end
end
