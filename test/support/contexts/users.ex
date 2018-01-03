require Passport.Repo

defmodule Passport.Support.Users do
  alias Passport.Support.User
  alias Passport.Repo
  import Ecto.Query

  def find_user_by_email(email) do
    User
    |> where(email: ^email)
    |> Repo.primary().one()
  end
end
