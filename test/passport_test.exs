defmodule PassportTest do
  use Passport.Support.DataCase

  describe "change_password(entity, params)" do
    test "allows changing a entity's password" do
      entity = insert(:user)

      assert {:ok, entity} = Passport.reset_password(entity, %{
        password: "old_pass",
        password_confirmation: "old_pass"
      })

      assert {:ok, entity} = Passport.check_authenticatable(entity, "old_pass")

      assert {:error, changeset} = Passport.change_password(entity, %{
        old_password: "old_pass_not_correct",
        password: "new_pass",
        password_confirmation: "new_pass",
      })

      assert {"old password does not match", []} == changeset.errors[:password]

      assert {:ok, entity} = Passport.change_password(entity, %{
        old_password: "old_pass",
        password: "new_pass",
        password_confirmation: "new_pass",
      })

      assert {:ok, _entity} = Passport.check_authenticatable(entity, "new_pass")
    end
  end
end
