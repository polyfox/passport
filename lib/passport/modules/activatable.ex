defmodule Passport.Activatable do
  @moduledoc """
  Affects whether an
  """
  import Ecto.Changeset

  defmacro schema_fields do
    quote do
      field :active, :boolean, default: true
      field :activated_at, :utc_datetime
    end
  end

  @doc """
  Changeset for modifying the active state of the record
  """
  @spec changeset(term, map) :: Ecto.Changeset.t
  def changeset(record, params) do
    record
    |> cast(params, [:active])
  end

  @spec activate(term) :: Ecto.Changeset.t
  def activate(record) do
    changeset(record, %{active: true})
  end

  @spec deactivate(term) :: Ecto.Changeset.t
  def deactivate(record) do
    changeset(record, %{active: false})
  end
end