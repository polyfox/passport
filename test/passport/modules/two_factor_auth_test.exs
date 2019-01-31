defmodule Passport.TwoFactorAuthTest do
  use Passport.Support.DataCase
  alias Passport.TwoFactorAuth

  describe "changeset(&1, &2, :disable)" do
    test "disable all tfa parameters" do
      user = insert(:user)
      {:ok, user} = Passport.initialize_tfa(user)
      assert user.tfa_enabled
      assert user.tfa_otp_secret_key
      refute user.unconfirmed_tfa_otp_secret_key

      {:ok, user} =
        user
        |> TwoFactorAuth.changeset(%{}, :disable)
        |> Passport.Repo.primary().update()

      refute user.tfa_enabled
      refute user.tfa_otp_secret_key
      refute user.unconfirmed_tfa_otp_secret_key
    end
  end

  describe "changeset(&1, &2, :initialize)" do
    test "initializes a valid tfa setup" do
      user = insert(:user, tfa_otp_secret_key: nil)
      refute user.tfa_enabled
      refute user.tfa_otp_secret_key
      refute user.unconfirmed_tfa_otp_secret_key

      {:ok, user} =
        user
        |> TwoFactorAuth.changeset(%{}, :initialize)
        |> Passport.Repo.primary().update()

      assert user.tfa_enabled
      assert user.tfa_otp_secret_key
      refute user.unconfirmed_tfa_otp_secret_key
    end
  end
end
