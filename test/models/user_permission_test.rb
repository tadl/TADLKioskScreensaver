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

  test "ordinary permission changes preserve a bootstrapped admin" do
    admin = users(:one)
    ordinary = admin.user_permissions.find_by!(permission: permissions(:one))

    ordinary.save!
    assert_predicate admin.reload, :admin?

    ordinary.destroy!
    assert_predicate admin.reload, :admin?
  end

  test "default staff provisioning preserves a new admin" do
    admin = User.create!(email: "bootstrap-admin@example.com", admin: true)

    assert_predicate admin.reload, :admin?
  end

  test "changing an admin role revokes admin access" do
    role = UserPermission.create!(user: @target, permission: @admin_permission)
    assert_predicate @target.reload, :admin?

    role.update!(permission: permissions(:one))
    assert_not @target.reload.admin?
  end

  test "moving an admin role synchronizes both users" do
    role = UserPermission.create!(user: @target, permission: @admin_permission)
    role.update!(user: @manager)

    assert_not @target.reload.admin?
    assert_predicate @manager.reload, :admin?
  end
end
