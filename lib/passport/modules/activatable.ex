defmodule Passport.Activatable do
  @moduledoc """
  Affects a Record's 'active' state
  """
  import Ecto.Changeset

  defmacro schema_fields(options \\ []) do
    timestamp_type = Keyword.get(options, :timestamp_type, :utc_datetime_usec)
    quote do
      if Passport.Config.activatable_is_flag(__MODULE__) do
        field :active, :boolean, default: true
      else
        field :activated_at, unquote(timestamp_type)
      end
    end
  end

  defmacro routes(_opts \\ []) do
    quote do
    end
  end

  def migration_fields(mod) do
    [
      "# Activatable",
      if Passport.Config.activatable_is_flag(mod) do
        "add :active, :boolean, default: true"
      else
        "add :activated_at, :utc_datetime_usec"
      end,
    ]
  end

  def migration_indices(_mod), do: []

  @doc """
  Changeset for modifying the active state of the record
  """
  @spec changeset(term, map) :: Ecto.Changeset.t
  def changeset(record, params) do
    if Passport.Config.activatable_is_flag(record) do
      cast(record, params, [:active])
    else
      cast(record, params, [:activated_at])
    end
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
