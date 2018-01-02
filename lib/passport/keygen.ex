defmodule Passport.Keygen do
  require Base

  # Stole the Digest code from here with a spin on it
  # https://github.com/techgaun/http_digex/blob/master/lib/digest_auth.ex

  @spec random_string(integer) :: String.t
  def random_string(len) do
    len
    |> :crypto.strong_rand_bytes
    |> Base.url_encode64
    |> binary_part(0, len)
  end

  @spec random_string32(integer) :: String.t
  def random_string32(len) do
    len
    |> :crypto.strong_rand_bytes
    |> Base.encode32
    |> binary_part(0, len)
  end
end
