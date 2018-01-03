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
    {:password_hash_field, :password_hash},
    # Whether Activatable is a single flag :active or a timestamp :activated_at
    {:activatable_is_flag, true},
    {:otp_header_name, "x-passport-otp"},
  ]
  |> Enum.each(fn {name, default} ->
    def unquote(name)(namespace \\ nil) do
      get_env(namespace, unquote(name), unquote(default))
    end
  end)

  def sessions_client do
    Application.get_env(:passport, :sessions_client)
  end

  def error_view do
    Application.get_env(:passport, :error_view)
  end

  @doc """
  Checks if the entity supports TFA
  """
  @spec feature_two_factor_auth?(entity :: term) :: boolean
  def feature_two_factor_auth?(entity) do
    # TODO: this should check if the entity has the 2fa module loaded
    true
  end
end
