defmodule Passport.Lockable do
  import Ecto.Changeset
  import Ecto.Query

  defmacro schema_fields(options \\ []) do
    timestamp_type = Keyword.get(options, :timestamp_type, :utc_datetime_usec)
    quote do
      field :failed_attempts, :integer, default: 0
      field :locked_at,       unquote(timestamp_type)
      field :lock_changed,    :boolean, virtual: true, default: false
    end
  end

  defmacro routes(_opts \\ []) do
    quote do
    end
  end

  def migration_fields(_mod) do
    [
      "# Lockable",
      "add :failed_attempts, :integer, default: 0",
      "add :locked_at,       :utc_datetime_usec",
    ]
  end

  def migration_indices(_mod), do: []

  @spec track_failed_attempts(Ecto.Query.t | module, String.t) :: Ecto.Query.t
  def track_failed_attempts(query, _remote_ip) do
    query
    |> update(inc: [failed_attempts: 1])
  end

  @spec try_lock(Ecto.Query.t | module, non_neg_integer, atom) :: {boolean, Ecto.Query.t}
  def try_lock(query, failed_attenmpts, _reason) do
    if failed_attenmpts > 2 do
      now = Passport.Util.generate_timestamp_for(query, :locked_at)
      {true, update(query, [u], set: [locked_at: ^now])}
    else
      {false, query}
    end
  end

  @spec clear_failed_attempts(Ecto.Changeset.t) :: Ecto.Changeset.t
  def clear_failed_attempts(changeset) do
    changeset
    |> change()
    |> put_change(:failed_attempts, 0)
  end

  @spec unlock_changeset(Ecto.Changeset.t) :: Ecto.Changeset.t
  def unlock_changeset(changeset) do
    changeset
    |> put_change(:locked_at, nil)
  end

  @spec locked?(term) :: boolean
  def locked?(entity) do
    !!entity.locked_at
  end
end
