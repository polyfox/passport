defmodule Passport.Trackable do
  import Ecto.Changeset

  defmacro schema_fields do
    quote do
      field :sign_in_count, :integer, default: 0
      field :current_sign_in_at, :utc_datetime
      field :current_sign_in_ip, :string
      field :last_sign_in_at, :utc_datetime
      field :last_sign_in_ip, :string
    end
  end

  defp format_remote_ip({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end

  @spec track_sign_in(Ecto.Changeset.t, remote_ip :: term) :: {:ok, User.t} | {:error, term}
  def track_sign_in(changeset, remote_ip) do
    changeset
    # probably shouldn't do that, but instead use the Ecto.Query update inc or something
    |> put_change(:sign_in_count, (get_field(changeset, :sign_in_count) || 0) + 1)
    |> put_change(:last_sign_in_ip, get_field(changeset, :current_sign_in_ip))
    |> put_change(:last_sign_in_at, get_field(changeset, :current_sign_in_at))
    |> put_change(:current_sign_in_ip, format_remote_ip(remote_ip))
    |> put_change(:current_sign_in_at, DateTime.utc_now())
  end
end
