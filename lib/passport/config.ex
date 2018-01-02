defmodule Passport.Config do
  @moduledoc """
  Module for handling passport's configuration
  """

  def namespace_for(nil), do: nil
  def namespace_for(atom) when is_atom(atom), do: atom
  def namespace_for(%Ecto.Changeset{data: data}), do: namespace_for(data)
  def namespace_for(%{__struct__: st}), do: st

  def get_env(namespace, name, default \\ nil) do
    ns = namespace_for(namespace)
    case Application.get_env(:passport, ns) do
      nil -> Application.get_env(:passport, name, default)
      conf -> Keyword.get(conf, name, default)
    end
  end

  [
    {:password_hash_field, :password_hash}
  ]
  |> Enum.each(fn {name, default} ->
    def unquote(name)(namespace \\ nil) do
      get_env(namespace, unquote(name), unquote(default))
    end
  end)
end
