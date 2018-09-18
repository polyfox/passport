defmodule PassportTest do
  use Passport.Support.DataCase

  describe "change_password/2" do
    test "allows changing the entity's password" do
      entity = insert(:user)

      assert {:ok, entity} = Passport.reset_password(entity, %{
        password: "old_pass",
        password_confirmation: "old_pass"
      })

      assert {:ok, entity} = Passport.check_authenticatable(entity, "old_pass")

      assert {:error, changeset} = Passport.change_password(entity, %{
        password: "new_pass",
        password_confirmation: "not_new_pass",
      })

      assert {"does not match password", [validation: :confirmation]} == changeset.errors[:password_confirmation]

      assert {:ok, entity} = Passport.change_password(entity, %{
        password: "new_pass",
        password_confirmation: "new_pass",
      })

      assert {:ok, _entity} = Passport.check_authenticatable(entity, "new_pass")
    end
  end

  describe "update_password/2" do
    test "allows updating a entity's password" do
      entity = insert(:user)

      assert {:ok, entity} = Passport.reset_password(entity, %{
        password: "old_pass",
        password_confirmation: "old_pass"
      })

      assert {:ok, entity} = Passport.check_authenticatable(entity, "old_pass")

      assert {:error, changeset} = Passport.update_password(entity, %{
        old_password: "old_pass_not_correct",
        password: "new_pass",
        password_confirmation: "new_pass",
      })

      assert {"old password does not match", []} == changeset.errors[:old_password]

      assert {:error, changeset} = Passport.update_password(entity, %{
        old_password: "old_pass",
        password: "new_pass",
        password_confirmation: "not_new_pass",
      })

      assert {"does not match password", [validation: :confirmation]} == changeset.errors[:password_confirmation]

      assert {:ok, entity} = Passport.update_password(entity, %{
        old_password: "old_pass",
        password: "new_pass",
        password_confirmation: "new_pass",
      })

      assert {:ok, _entity} = Passport.check_authenticatable(entity, "new_pass")
    end
  end
end
