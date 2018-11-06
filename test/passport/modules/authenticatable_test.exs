defmodule Passport.AuthenticatableTest do
  use Passport.Support.DataCase
  alias Passport.Authenticatable

  describe "changeset(&1, &2, :update)" do
    setup tags do
      entity = insert(:user)
      assert {:ok, entity} = Passport.reset_password(entity, %{
        password: "old_pass",
        password_confirmation: "old_pass"
      })

      entity = %{entity | old_password: nil, password: nil, password_confirmation: nil}

      {:ok, Map.put(tags, :entity, entity)}
    end

    test "will have an error if the old_password does not match", %{entity: entity} do
      changeset = Authenticatable.changeset(entity, %{
        old_password: "old_password",
      }, :update)

      assert [
        old_password: {"does not match old password", []},
      ] == changeset.errors
    end

    test "will have an error if the old_password matches, but no new password is given", %{entity: entity} do
      changeset = Authenticatable.changeset(entity, %{
        old_password: "old_pass",
      }, :update)

      assert [
        password: {"can't be blank", [validation: :required]},
        password_confirmation: {"can't be blank", [validation: :required]},
      ] == changeset.errors
    end

    test "will have an error if the old_password matches, a new password is given, but no confirmation", %{entity: entity} do
      changeset = Authenticatable.changeset(entity, %{
        old_password: "old_pass",
        password: "new_pass",
      }, :update)

      assert [
        password_confirmation: {"can't be blank", [validation: :required]},
      ] == changeset.errors
    end

    test "will have an error if the old_password matches, a new password is given, but confirmation doesn't match", %{entity: entity} do
      changeset = Authenticatable.changeset(entity, %{
        old_password: "old_pass",
        password: "new_pass",
        password_confirmation: "new_pass_maybe",
      }, :update)

      assert [
        password_confirmation: {"does not match password", [validation: :confirmation]},
      ] == changeset.errors
    end

    test "can change password if all fields are correct", %{entity: entity} do
      changeset = Authenticatable.changeset(entity, %{
        old_password: "old_pass",
        password: "new_pass",
        password_confirmation: "new_pass",
      }, :update)

      assert [] == changeset.errors
    end
  end
end
