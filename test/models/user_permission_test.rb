require "test_helper"

class UserPermissionTest < ActiveSupport::TestCase
  setup do
    @manage_users = Permission.find_or_create_by!(name: "manage_users")
    @admin_permission = permissions(:admin)
    @manager = User.create!(email: "manager@example.com", name: "Manager")
    @target = User.create!(email: "target@example.com", name: "Target")
    UserPermission.create!(user: @manager, permission: @manage_users)
  end

  test "non-admin user managers cannot elevate themselves or assign admin" do
    ability = Ability.new(@manager)
    own_permission = @manager.user_permissions.find_by!(permission: @manage_users)
    target_permission = @target.user_permissions.find_by!(permission: permissions(:two))

    assert ability.cannot?(:update, own_permission)
    assert ability.can?(:update, target_permission)

    Current.user = @manager
    target_permission.permission = @admin_permission

    assert_not target_permission.valid?
    assert_includes target_permission.errors[:permission], "cannot be assigned by a non-admin"
  ensure
    Current.user = nil
  end

  test "non-admin user managers cannot remove admin permissions" do
    admin = users(:one)
    admin_permission = admin.user_permissions.find_or_create_by!(permission: @admin_permission)

    Current.user = @manager

    assert_not admin_permission.destroy
    assert_predicate admin_permission, :persisted?
  ensure
    Current.user = nil
  end
end
