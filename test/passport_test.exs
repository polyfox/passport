defmodule PassportTest do
  use Passport.Support.DataCase

  describe "change_password/2" do
    setup tags do
      entity = insert(:user)

      {:ok, entity} = Passport.reset_password(entity, %{
        password: "old_pass",
        password_confirmation: "old_pass"
      })

      entity = %{entity | old_password: nil, password: nil, password_confirmation: nil}
      {:ok, Map.put(tags, :entity, entity)}
    end

    test "allows changing the entity's password", %{entity: entity} do
      assert {:ok, entity} = Passport.check_authenticatable(entity, "old_pass")

      assert {:error, changeset} = Passport.change_password(entity, %{
        password: "new_pass",
      })

      assert [
        password_confirmation: {"can't be blank", [validation: :required]},
      ] == changeset.errors

      assert {:error, changeset} = Passport.change_password(entity, %{
        password: "new_pass",
        password_confirmation: "not_new_pass",
      })

      assert [
        password_confirmation: {"does not match password", [validation: :confirmation]},
      ] == changeset.errors

      assert {:ok, entity} = Passport.change_password(entity, %{
        password: "new_pass",
        password_confirmation: "new_pass",
      })

      assert {:ok, _entity} = Passport.check_authenticatable(entity, "new_pass")
    end

    test "when no parameters are given, nothing changes", %{entity: entity} do
      assert {:ok, entity} = Passport.check_authenticatable(entity, "old_pass")
      assert {:ok, entity} = Passport.change_password(entity, %{})
      assert {:ok, _entity} = Passport.check_authenticatable(entity, "old_pass")
    end
  end

  describe "update_password/2" do
    setup tags do
      entity = insert(:user)

      {:ok, entity} = Passport.reset_password(entity, %{
        password: "old_pass",
        password_confirmation: "old_pass"
      })

      entity = %{entity | old_password: nil, password: nil, password_confirmation: nil}

      {:ok, Map.put(tags, :entity, entity)}
    end

    test "allows updating a entity's password", %{entity: entity} do
      assert {:ok, entity} = Passport.check_authenticatable(entity, "old_pass")

      assert {:error, changeset} = Passport.update_password(entity, %{
        old_password: "old_pass_not_correct",
        password: "new_pass",
        password_confirmation: "new_pass",
      })

      assert [
        old_password: {"does not match old password", []},
      ] == changeset.errors

      assert {:error, changeset} = Passport.update_password(entity, %{
        old_password: "old_pass",
        password: "new_pass",
      })

      assert [
        password_confirmation: {"can't be blank", [validation: :required]}
      ] == changeset.errors

      assert {:error, changeset} = Passport.update_password(entity, %{
        old_password: "old_pass",
        password: "new_pass",
        password_confirmation: "not_new_pass",
      })

      assert [
        password_confirmation: {"does not match password", [validation: :confirmation]}
      ] == changeset.errors

      assert {:ok, entity} = Passport.update_password(entity, %{
        old_password: "old_pass",
        password: "new_pass",
        password_confirmation: "new_pass",
      })

      assert {:ok, _entity} = Passport.check_authenticatable(entity, "new_pass")
    end

    test "when no parameters are given, nothing changes", %{entity: entity} do
      assert {:ok, entity} = Passport.check_authenticatable(entity, "old_pass")
      assert {:ok, entity} = Passport.update_password(entity, %{})
      assert {:ok, _entity} = Passport.check_authenticatable(entity, "old_pass")
    end
  end
end
