defmodule Passport.SessionControllerTest do
  use Passport.Support.Web.ConnCase, async: false

  describe "POST /account/login" do
    test "creates a new session with basic auth", %{conn: conn} do
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

    test "creates a new session with tfa enabled, using otp", %{conn: base_conn} do
      user = insert(:user)
      {:ok, user} = Passport.initialize_tfa(user)
      conn = post base_conn, "/account/login", %{
        "email" => user.email,
        "password" => user.password
      }

      assert json_response(conn, 401)

      conn = post base_conn, "/account/login", %{
        "email" => user.email,
        "password" => user.password,
        "otp" => :pot.totp(user.tfa_otp_secret_key)
      }

      assert json_response(conn, 201)
    end

    test "creates a new session with tfa enabled, using recovery_token", %{conn: base_conn} do
      user = insert(:user)
      {:ok, user} = Passport.initialize_tfa(user)
      conn = post base_conn, "/account/login", %{
        "email" => user.email,
        "password" => user.password
      }

      assert json_response(conn, 401)

      [token | rest] = user.tfa_recovery_tokens
      conn = post base_conn, "/account/login", %{
        "email" => user.email,
        "password" => user.password,
        "recovery_token" => token
      }

      assert json_response(conn, 201)

      user = Passport.Repo.replica().get(Passport.Support.User, user.id)

      assert rest == user.tfa_recovery_tokens
    end

    test "fails to create new session with tfa enabled, using incorrect recovery_token", %{conn: base_conn} do
      user = insert(:user)
      {:ok, user} = Passport.initialize_tfa(user)
      old_tokens = user.tfa_recovery_tokens
      conn = post base_conn, "/account/login", %{
        "email" => user.email,
        "password" => user.password,
        "recovery_token" => "00000000"
      }

      assert json_response(conn, 401)
      user = reload_record(user)
      assert 1 == user.tfa_attempts_count
      assert old_tokens == user.tfa_recovery_tokens
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
      user = reload_record(user)
      assert 1 == user.failed_attempts

      assert data["errors"]
      assert [%{"code" => "unauthorized", "detail" => "Invalid email or password.", "status" => "401", "title" => "Unauthorized"}] == data["errors"]
    end

    test "will error if the account is locked", %{conn: conn} do
      user = insert(:user, locked_at: DateTime.utc_now() |> DateTime.truncate(:second))
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

    test "will error if entity has tfa enabled, but no secret key", %{conn: conn} do
      user = insert(:user, tfa_enabled: true, tfa_otp_secret_key: nil)
      conn = post conn, "/account/login", %{
        "email" => user.email,
        "password" => user.password
      }

      assert json_response(conn, 428)
    end

    test "will error if no parameters are provided", %{conn: conn} do
      conn = post conn, "/account/login", %{}

      assert json_response(conn, 422)
    end
  end

  describe "DELETE /account/login" do
    test "destroys a session", %{conn: conn} do
      user = insert(:user)
      conn = put_req_header(conn, "authorization", "Bearer #{user.id}")
      conn = delete conn, "/account/login"

      assert response(conn, 204)
    end
  end
end
