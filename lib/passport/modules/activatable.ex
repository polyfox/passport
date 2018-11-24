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

  defp activatable_is_flag?(record) do
    Passport.Config.activatable_is_flag(record)
  end

  @doc """
  Changeset for modifying the active state of the record
  """
  @spec changeset(term, map) :: Ecto.Changeset.t
  def changeset(entity, params) do
    if activatable_is_flag?(entity) do
      cast(entity, params, [:active])
    else
      cast(entity, params, [:activated_at])
    end
  end

  @spec activate(term) :: Ecto.Changeset.t
  def activate(entity) do
    if activatable_is_flag?(entity) do
      changeset(entity, %{active: true})
    else
      activated_at = Passport.Util.generate_timestamp_for(entity, :activated_at)
      changeset(entity, %{activated_at: activated_at})
    end
  end

  @spec deactivate(term) :: Ecto.Changeset.t
  def deactivate(entity) do
    changeset(entity, %{active: false, activated_at: nil})
  end

  @spec activated?(term) :: boolean
  def activated?(entity) do
    if activatable_is_flag?(entity) do
      entity.active
    else
      !!entity.activated_at
    end
  end
end
