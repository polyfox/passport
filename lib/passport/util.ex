defmodule Passport.Util do
  @moduledoc """
  Some utility functions for passport
  """

  @doc """
  Takes a changeset or entity record and a field name, this will generate a DateTime of the
  correct type for that field.
  """
  @spec generate_timestamp_for(Ecto.Changeset.t | term, atom) :: NaiveDateTime.t | DateTime.t
  def generate_timestamp_for(record, field) do
    case Passport.Config.module_for(record).__schema__(:type, field) do
      :naive_datetime -> NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      :naive_datetime_usec -> NaiveDateTime.utc_now()
      :utc_datetime -> DateTime.utc_now() |> DateTime.truncate(:second)
      :utc_datetime_usec -> DateTime.utc_now()
    end
  end
end
