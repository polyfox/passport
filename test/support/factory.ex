require Passport.Repo

defmodule Passport.Support.Factory do
  use ExMachina.Ecto, repo: Passport.Repo.primary()

  @user_password_hash Bcrypt.hash_pwd_salt("password")

  def user_factory do
    %Passport.Support.User{
      confirmed_at: DateTime.utc_now(),
      email: sequence(:email, &"user#{&1}@example.com"),
      username: sequence(:username, &"user#{&1}"),
      tfa_otp_secret_key: Passport.TwoFactorAuth.generate_secret_key(),
      # not a proper hash, but is just a placeholder
      password_hash: @user_password_hash,
      password: "password",
      password_confirmation: "password",
    }
  end
end
