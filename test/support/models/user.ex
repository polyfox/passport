require Passport

defmodule Passport.Support.User do
  use Ecto.Schema
  import Ecto.Changeset

  Passport.schema()

  schema "users" do
    timestamps(type: :utc_datetime)

    field :email, :string
    field :username, :string

    Passport.schema_fields()
  end

  def changeset(record, params) do
    record
    |> cast(params, [
      :email,
      :username
    ])
    |> Passport.changeset(params, :update)
  end
end
