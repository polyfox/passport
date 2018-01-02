defmodule Passport.Rememberable do
  defmacro schema_fields do
    quote do
      field :remember_created_at, :utc_datetime
    end
  end
end
