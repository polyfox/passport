defmodule Passport.Repo do
  @moduledoc """
  Proxy module for ecto repo operations.
  """

  @primary_repo Application.get_env(:passport, :primary_repo)
  @replica_repo Application.get_env(:passport, :replica_repo)

  defmacro primary do
    @primary_repo
  end

  defmacro replica do
    @replica_repo
  end
end
