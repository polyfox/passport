defmodule Passport.ConfigTest do
  use Passport.Support.DataCase
  alias Passport.Config

  describe "module_for/1" do
    test "can retrieve schema from schema" do
      assert Passport.Support.User == Config.module_for(Passport.Support.User)
    end

    test "can retrieve schema from changeset" do
      changeset =
        %Passport.Support.User{}
        |> Passport.Support.User.changeset(%{email: "john@example.com", username: "jdoe"})

      assert Passport.Support.User == Config.module_for(changeset)
    end

    test "can retrieve schema from query" do
      import Ecto.Query

      query =
        Passport.Support.User
        |> where(username: "jdoe")

      assert Passport.Support.User == Config.module_for(query)
    end

    test "can retrieve schema from record" do
      assert Passport.Support.User == Config.module_for(%Passport.Support.User{})
    end
  end

  describe "features?/2" do
    test "will return true if 2fa is enabled for the given entity" do
      user = insert(:user)
      assert Config.features?(user, :activatable)
      assert Config.features?(user, :authenticatable)
      assert Config.features?(user, :confirmable)
      assert Config.features?(user, :lockable)
      assert Config.features?(user, :recoverable)
      assert Config.features?(user, :rememberable)
      assert Config.features?(user, :trackable)
      assert Config.features?(user, :two_factor_auth)
    end
  end
end
