defmodule Passport.TwoFactorAuthControllerTest do
  use Passport.Support.Web.ConnCase

  describe "POST /account/confirm/tfa" do
    test "can reset tfa_otp_secret_key", %{conn: conn} do
      user = insert(:user)
      old_tfa_otp_secret_key = user.tfa_otp_secret_key
      assert old_tfa_otp_secret_key
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => user.password
      }

      data = json_response(conn, 201)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)
      assert user.id == data["id"]
      assert user.tfa_otp_secret_key == data["tfa_otp_secret_key"]
      refute old_tfa_otp_secret_key == data["tfa_otp_secret_key"]
    end

    test "can reset tfa_otp_secret_key with tfa enabled and otp provided", %{conn: conn} do
      user = insert(:user, tfa_enabled: true)
      old_tfa_otp_secret_key = user.tfa_otp_secret_key
      assert old_tfa_otp_secret_key
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => user.password,
        "otp" => :pot.totp(user.tfa_otp_secret_key)
      }

      data = json_response(conn, 201)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)
      assert user.id == data["id"]
      assert user.tfa_otp_secret_key == data["tfa_otp_secret_key"]
      refute old_tfa_otp_secret_key == data["tfa_otp_secret_key"]
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

    test "requires original otp before resetting", %{conn: conn} do
      user = insert(:user, tfa_enabled: true)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => user.password
      }

      json_response(conn, 401)
    end
  end

  describe "PUT /account/confirm/tfa" do
    test "confirm tfa is valid", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.prepare_tfa_confirmation(user)
      conn = put conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => user.password,
        "otp" => :pot.totp(user.tfa_otp_secret_key)
      }
      data = json_response(conn, 200)
      assert user.id == data["id"]
      assert user.email == data["email"]
      assert user.username == data["username"]
      user = Passport.Repo.replica().get(user.__struct__, user.id)

      assert user.tfa_enabled
    end
  end
end
