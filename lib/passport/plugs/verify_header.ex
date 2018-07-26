# Based on https://github.com/ueberauth/guardian/blob/master/lib/guardian/plug/verify_header.ex
defmodule Passport.Plug.VerifyHeader do
  @moduledoc """
  Use this plug to verify a token contained in the header.

  You should set the value of the Authorization header to:

      Authorization: <jwt>

  ## Example

      plug Passport.Plug.VerifyHeader

  ## Example

      plug Passport.Plug.VerifyHeader, key: :secret

  Verifying the session will update the claims on the request,
  available with Passport.Plug.claims/1

  In the case of an error, the claims will be set to { :error, reason }

  A "realm" can be specified when using the plug.
  Realms are like the name of the token and allow many tokens
  to be sent with a single request.

      plug Passport.Plug.VerifyHeader, realm: "Bearer"

  When a realm is not specified,
  the first authorization header found is used, and assumed to be a raw token

  #### example

      plug Passport.Plug.VerifyHeader

      # will take the first auth header
      # Authorization: <jwt>
  """
  import Passport.APIHelper

  def init(opts \\ %{}) do
    opts_map = Enum.into(opts, %{})
    realm = Map.get(opts_map, :realm)
    if realm do
      {:ok, reg} = Regex.compile("#{realm}\:?\s+(.*)$", "i")
      Map.put(opts_map, :realm_reg, reg)
    else
      opts_map
    end
  end

  def call(conn, opts) do
    verify_token(conn, fetch_token(conn, opts), opts)
  end

  # TODO: maybe move the send into call, and check if token is set
  defp verify_token(conn, nil, _), do: send_unauthenticated(conn)
  defp verify_token(conn, "", _), do: send_unauthenticated(conn)

  defp verify_token(conn, token, _opts) do
    case Passport.Sessions.get_session(token) do
      {:ok, claims} ->
        set_current_claims(conn, claims)
      {:error, :locked} ->
        send_locked(conn)
      {:error, _reason} ->
        send_unauthorized(conn)
    end
  end

  defp fetch_token(conn, opts) do
    fetch_token(conn, opts, Plug.Conn.get_req_header(conn, "authorization"))
  end

  # TODO: fallback to query params
  defp fetch_token(_, _, []), do: nil

  defp fetch_token(conn, opts = %{realm_reg: reg}, [token|tail]) do
    trimmed_token = String.trim(token)
    case Regex.run(reg, trimmed_token) do
      [_, match] -> String.trim(match)
      _ -> fetch_token(conn, opts, tail)
    end
  end

  defp fetch_token(_, _, [token|_tail]), do: String.trim(token)

  defp set_current_claims(conn, claims) do
    Enum.reduce(claims, conn, fn {k, v}, c ->
      Plug.Conn.assign(c, k, v)
    end)
  end
end
