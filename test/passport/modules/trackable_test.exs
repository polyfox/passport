defmodule Passport.TrackableTest do
  use Passport.Support.DataCase
  alias Passport.Trackable

  describe "format_remote_ip/1" do
    test "formats a ipv4 address" do
      assert "127.0.0.1" == Trackable.format_remote_ip({127, 0, 0, 1})
      assert "192.168.0.107" == Trackable.format_remote_ip({192, 168, 0, 107})
    end

    test "formats a ipv6 address" do
      assert "::1" == Trackable.format_remote_ip({0, 0, 0, 0, 0, 0, 0, 1})
      assert "::ffff:172.18.0.1" == Trackable.format_remote_ip({0, 0, 0, 0, 0, 65535, 44050, 1})
    end
  end
end
