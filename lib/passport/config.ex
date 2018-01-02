defmodule Passport.Config do
  @moduledoc """
  Module for handling passport's configuration
  """

  [
    {:password_hash_field, :password_hash}
  ]
  |> Enum.each(fn {name, default} ->
    def unquote(name)() do
      Application.get_env(:passport, unquote(name), unquote(default))
    end
  end)
end
