defmodule Passport.TwoFactorAuthControllerTest do
  use Passport.Support.Web.ConnCase

  describe "POST /account/confirm/tfa" do
    test "creates a tfa confirmation request", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => user.password
      }

      data = json_response(conn, 201)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)
      assert user.id == data["id"]
      assert user.tfa_confirmation_token == data["tfa_confirmation_token"]
    end

    test "cannot create new confirmation request if password is incorrect", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => "altpassw"
      }

      json_response(conn, 401)
    end

    test "cannot create new confirmation request if email is incorrect", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => "somedude@example.com",
        "password" => user.password
      }

      json_response(conn, 401)
    end

    test "cannot activate tfa again", %{conn: conn} do
      user = insert(:user, tfa_enabled: true)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => user.password
      }

      json_response(conn, 401)
    end
  end

  describe "GET /account/confirm/tfa/:token" do
    test "retrieves entity information for tfa confirmation", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.prepare_tfa_confirmation(user)
      conn = post conn, "/account/confirm/tfa/#{user.tfa_confirmation_token}", %{
        "otp" => :pot.totp(user.tfa_otp_secret_key)
      }

      json_response(conn, 204)
    end
  end

  describe "POST /account/confirm/tfa/:token" do
    test "confirm tfa is valid", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.prepare_tfa_confirmation(user)
      conn = post conn, "/account/confirm/tfa/#{user.tfa_confirmation_token}", %{
        "otp" => :pot.totp(user.tfa_otp_secret_key)
      }
      response(conn, 204)
      user = Passport.Repo.replica().get(user.__struct__, user.id)

      assert user.tfa_enabled
      assert user.tfa_confirmed_at
      refute user.tfa_confirmation_token
    end
  end

  describe "DELETE /account/confirm/tfa/:token" do
    test "cancel a tfa confirmation request", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.prepare_tfa_confirmation(user)
      conn = delete conn, "/account/confirm/tfa/#{user.tfa_confirmation_token}"

      response(conn, 204)
      user = Passport.Repo.replica().get(user.__struct__, user.id)

      refute user.tfa_enabled
      refute user.tfa_confirmed_at
      refute user.tfa_confirmation_token
    end
  end
end
