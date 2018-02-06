defmodule Passport.TwoFactorAuthControllerTest do
  use Passport.Support.Web.ConnCase

  describe "POST /account/reset/tfa" do
    test "can reset tfa_otp_secret_key without tfa enabled", %{conn: conn} do
      user = insert(:user)
      old_tfa_otp_secret_key = user.tfa_otp_secret_key
      assert old_tfa_otp_secret_key
      conn = post conn, "/account/reset/tfa", %{
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
      conn = post conn, "/account/reset/tfa", %{
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

    test "can reset tfa_otp_secret_key with tfa enabled and recovery_token provided", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.confirm_tfa(user)

      old_tokens = user.tfa_recovery_tokens
      [token | rest] = user.tfa_recovery_tokens
      assert token

      conn = post conn, "/account/reset/tfa", %{
        "email" => user.email,
        "password" => user.password,
        "recovery_token" => token
      }

      data = json_response(conn, 201)
      user = Passport.Repo.replica().get(Passport.Support.User, user.id)

      refute Enum.member?(user.tfa_recovery_tokens, token)
      # consumes the token
      assert rest == user.tfa_recovery_tokens
    end

    test "cannot reset if password is incorrect", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => "altpassw"
      }

      json_response(conn, 401)
    end

    test "cannot reset if email is incorrect", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => "somedude@example.com",
        "password" => user.password
      }

      json_response(conn, 401)
    end

    test "requires original otp before resetting", %{conn: conn} do
      user = insert(:user, tfa_enabled: true)
      conn = post conn, "/account/reset/tfa", %{
        "email" => user.email,
        "password" => user.password
      }

      json_response(conn, 401)
    end
  end

  describe "POST /account/confirm/tfa" do
    test "confirm tfa is valid", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.prepare_tfa_confirmation(user)
      conn = post conn, "/account/confirm/tfa", %{
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
