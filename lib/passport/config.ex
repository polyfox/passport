defmodule Passport.Config do
  @moduledoc """
  Module for handling passport's configuration
  """

  def module_for(nil), do: nil
  def module_for(atom) when is_atom(atom), do: atom
  def module_for(%Ecto.Changeset{data: data}), do: module_for(data)
  def module_for(%{__struct__: st}), do: st

  def get_env(namespace, name, default \\ nil) do
    ns = module_for(namespace)
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
    {:tfa_recovery_token_count, 10},
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

  @spec features?(entity :: term, feature :: atom) :: boolean
  def features?(entity, feature) do
    module_for(entity).passport_feature?(feature)
  end
end
