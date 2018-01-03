defmodule Passport.ConfigTest do
  use Passport.Support.DataCase
  alias Passport.Config

  describe "features?" do
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
