defmodule Passport.Rememberable do
  defmacro schema_fields(options \\ []) do
    timestamp_type = Keyword.get(options, :timestamp_type, :utc_datetime_usec)
    quote do
      field :remember_created_at, unquote(timestamp_type)
    end
  end

  defmacro routes(_opts \\ []) do
    quote do
    end
  end

  def migration_fields(_mod) do
    [
      "# Rememberable",
      "add :remember_created_at, :utc_datetime_usec",
    ]
  end

  def migration_indices(_mod), do: []
end
