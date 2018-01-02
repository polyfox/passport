defmodule Passport.Repo do
  @moduledoc """
  Proxy module for ecto repo operations.
  """

  @primary_repo Application.get_env(:passport, :primary_repo)
  @replica_repo Application.get_env(:passport, :replica_repo)

  def update(changeset_or_struct, opts \\ []) do
    @primary_repo.update(changeset_or_struct, opts)
  end

  def one(changeset_or_struct, opts \\ []) do
    @replica_repo.one(changeset_or_struct, opts)
  end
end
