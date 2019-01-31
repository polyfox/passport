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

      doc = json_response(conn, 201)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)
      assert user.tfa_otp_secret_key
      refute user.tfa_otp_secret_key == user.unconfirmed_tfa_otp_secret_key
      assert %{
        "id" => user.id,
        "email" => user.email,
        "username" => user.username,
        "unconfirmed_tfa_otp_secret_key" => assert(user.unconfirmed_tfa_otp_secret_key),
      } == doc
    end

    test "can reset tfa_otp_secret_key with tfa enabled and otp provided", %{conn: conn} do
      user = insert(:user, tfa_enabled: true)
      old_tfa_otp_secret_key = assert(user.tfa_otp_secret_key)
      conn = post conn, "/account/reset/tfa", %{
        "email" => user.email,
        "password" => user.password,
        "otp" => :pot.totp(user.tfa_otp_secret_key)
      }

      doc = json_response(conn, 201)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)
      refute user.tfa_otp_secret_key == doc["unconfirmed_tfa_otp_secret_key"]
      refute old_tfa_otp_secret_key == doc["unconfirmed_tfa_otp_secret_key"]
      assert %{
        "id" => user.id,
        "email" => user.email,
        "username" => user.username,
        "unconfirmed_tfa_otp_secret_key" => assert(user.unconfirmed_tfa_otp_secret_key),
      } == doc
    end

    test "can reset tfa_otp_secret_key with tfa enabled and recovery_token provided", %{conn: conn} do
      user = insert(:user)
      {:ok, user} = Passport.initialize_tfa(user)
      old_tfa_otp_secret_key = assert(user.tfa_otp_secret_key)

      [token | rest] = user.tfa_recovery_tokens
      assert token

      conn = post conn, "/account/reset/tfa", %{
        "email" => user.email,
        "password" => user.password,
        "recovery_token" => token,
      }

      doc = json_response(conn, 201)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)

      refute Enum.member?(user.tfa_recovery_tokens, token)
      # consumes the token
      assert rest == user.tfa_recovery_tokens

      refute user.tfa_otp_secret_key == doc["unconfirmed_tfa_otp_secret_key"]
      refute old_tfa_otp_secret_key == doc["unconfirmed_tfa_otp_secret_key"]
      assert %{
        "id" => user.id,
        "email" => user.email,
        "username" => user.username,
        "unconfirmed_tfa_otp_secret_key" => assert(user.unconfirmed_tfa_otp_secret_key),
      } == doc
    end

    test "cannot reset if password is incorrect", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => "altpassw"
      }

      json_response(conn, 401)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)
      refute user.unconfirmed_tfa_otp_secret_key
    end

    test "cannot reset if email is incorrect", %{conn: conn} do
      user = insert(:user)
      conn = post conn, "/account/confirm/tfa", %{
        "email" => "somedude@example.com",
        "password" => user.password
      }

      json_response(conn, 401)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)
      refute user.unconfirmed_tfa_otp_secret_key
    end

    test "requires original otp before resetting", %{conn: conn} do
      user = insert(:user, tfa_enabled: true)
      conn = post conn, "/account/reset/tfa", %{
        "email" => user.email,
        "password" => user.password
      }

      json_response(conn, 401)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)
      refute user.unconfirmed_tfa_otp_secret_key
    end
  end

  describe "POST /account/confirm/tfa" do
    test "confirm tfa is valid", %{conn: conn} do
      user = insert(:user, tfa_otp_secret_key: nil)
      {:ok, user} = Passport.prepare_tfa_confirmation(user)
      refute user.tfa_otp_secret_key
      assert user.unconfirmed_tfa_otp_secret_key
      conn = post conn, "/account/confirm/tfa", %{
        "email" => user.email,
        "password" => user.password,
        "otp" => :pot.totp(user.unconfirmed_tfa_otp_secret_key)
      }
      doc = json_response(conn, 200)


      user = Passport.Repo.replica().get(user.__struct__, user.id)

      assert user.tfa_enabled
      assert user.tfa_otp_secret_key
      assert user.tfa_recovery_tokens
      refute user.unconfirmed_tfa_otp_secret_key

      assert %{
        "id" => user.id,
        "email" => user.email,
        "username" => user.username,
        "tfa_recovery_tokens" => user.tfa_recovery_tokens,
      } == doc
    end
  end
end
