defmodule Passport.Lockable do
  import Ecto.Changeset
  import Ecto.Query

  defmacro schema_fields do
    quote do
      field :failed_attempts, :integer, default: 0
      field :locked_at, :utc_datetime
      field :lock_changed, :boolean, virtual: true, default: false
    end
  end

  defp perform_lock(changeset) do
    case get_field(changeset, :failed_attempts) do
      # we check if the failed_attempts as if (v + 1) here
      # since update_all wouldn't apply the changes to the changeset
      v when is_integer(v) and v >= 2 ->
        put_change(changeset, :locked_at, DateTime.utc_now())
      _ -> changeset
    end
  end

  def track_failed_attempts(changeset, _remote_ip) do
    changeset
    |> prepare_changes(fn cs ->
      id = cs.data.id
      cs.data.__struct__
      |> where(id: ^id)
      |> cs.repo.update_all(inc: [failed_attempts: 1])
      cs
    end)
    |> perform_lock
  end

  def clear_failed_attempts(changeset) do
    changeset
    |> put_change(:failed_attempts, 0)
  end
end
