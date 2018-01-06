defmodule Passport.Trackable do
  import Ecto.Changeset

  defmacro schema_fields(opts \\ []) do
    timestamp_type = Keyword.get(opts, :timestamp_type, :utc_datetime)
    quote do
      field :sign_in_count, :integer, default: 0
      field :current_sign_in_at, unquote(timestamp_type)
      field :current_sign_in_ip, :string
      field :last_sign_in_at, unquote(timestamp_type)
      field :last_sign_in_ip, :string
    end
  end

  defmacro routes(_opts \\ []) do
    quote do
    end
  end

  def migration_fields(_mod) do
    [
      "# Trackable",
      "add :sign_in_count, :integer, default: 0",
      "add :current_sign_in_at, :utc_datetime",
      "add :current_sign_in_ip, :string",
      "add :last_sign_in_at, :utc_datetime",
      "add :last_sign_in_ip, :string",
    ]
  end

  def migration_indices(_mod), do: []

  def format_remote_ip(tup) do
    tup
    |> :inet_parse.ntoa()
    |> to_string()
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
