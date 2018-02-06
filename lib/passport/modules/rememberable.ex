defmodule Passport.Rememberable do
  defmacro schema_fields(opts \\ []) do
    quote do
      field :remember_created_at, :utc_datetime
    end
  end

  defmacro routes(_opts \\ []) do
    quote do
    end
  end

  def migration_fields(_mod) do
    [
      "# Rememberable",
      "add :remember_created_at, :utc_datetime",
    ]
  end

  def migration_indices(_mod), do: []
end
