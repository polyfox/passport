defmodule Passport.Repo do
  @moduledoc """
  Proxy module for ecto repo operations.
  """

  defmacro primary do
    Application.get_env(:passport, :primary_repo)
  end

  defmacro replica do
    Application.get_env(:passport, :replica_repo)
  end
end
