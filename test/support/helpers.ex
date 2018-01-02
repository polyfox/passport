require Passport.Repo

defmodule Passport.Support.Helpers do
  def reload_user(user) do
    Passport.Repo.replica().get(Passport.Support.User, user.id)
  end
end
