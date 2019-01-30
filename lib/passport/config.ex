defmodule Passport.Config do
  @moduledoc """
  Module for handling passport's configuration
  """

  def module_for(nil), do: nil
  def module_for(atom) when is_atom(atom), do: atom
  def module_for(%Ecto.Changeset{data: data}), do: module_for(data)
  def module_for(%Ecto.Query{from: %{source: {_table, module}}}), do: module_for(module)
  def module_for(%st{}), do: st

  @doc """
  Retrieves a passport configured value given a namespace and name.

  Passport will first lookup the config as:
    config :passport, namespace, [name: value]

  If nothing is configured for the namespace, it will look at the root config instead.

    config :passport, name: value

  Example:

  Configuring the reset_password_length for users and leaving a default for anything else.

    config :passport, reset_password_length: 60
    config :passport, User, reset_password_length: 120

  get_env(User, :reset_password_length) would return 120

  While:

  get_env(nil, :reset_password_length) would return 60
  """
  @spec get_env(term | nil, atom, term) :: term
  def get_env(namespace, name, default \\ nil)
  def get_env(nil, name, default) do
    Application.get_env(:passport, name, default)
  end
  def get_env(namespace, name, default) do
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
    {:reset_password_token_length, 120},
    {:confirmation_token_length, 120},
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
