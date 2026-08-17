require "test_helper"

class UserKioskAccessTest < ActiveSupport::TestCase
  setup do
    @permission = Permission.find_or_create_by!(name: "manage_slides") do |permission|
      permission.description = "Can upload and manage slides"
    end
    @user = User.create!(
      email: "direct-kiosk-user@example.com",
      encrypted_password: "x" * 60,
      name: "Direct Kiosk User"
    )
    @group = KioskGroup.create!(name: "Woodmere", slug: "woodmere")
    @signage_kiosk = Kiosk.create!(
      name: "Woodmere Signage",
      slug: "woodmere-signage",
      catalog_url: "https://catalog.example.com/signage",
      kiosk_group: @group
    )
    @catalog_kiosk = Kiosk.create!(
      name: "Woodmere Catalog",
      slug: "woodmere-catalog",
      catalog_url: "https://catalog.example.com/catalog",
      kiosk_group: @group
    )
  end

  test "direct kiosk assignment grants one kiosk without granting the whole group" do
    user_permission = UserPermission.create!(user: @user, permission: @permission)
    user_permission.kiosks << @signage_kiosk

    assert_equal [@signage_kiosk.id], @user.accessible_kiosk_ids
    assert_equal [@group.id], @user.accessible_kiosk_group_ids

    ability = Ability.new(@user)
    assert ability.can?(:update, @signage_kiosk)
    assert ability.cannot?(:update, @catalog_kiosk)
    assert ability.can?(:create, Slide)
  end

  test "kiosk group assignment still grants every kiosk in the group" do
    user_permission = UserPermission.create!(user: @user, permission: @permission)
    user_permission.kiosk_groups << @group

    assert_equal [@catalog_kiosk.id, @signage_kiosk.id].sort, @user.accessible_kiosk_ids.sort

    ability = Ability.new(@user)
    assert ability.can?(:update, @signage_kiosk)
    assert ability.can?(:update, @catalog_kiosk)
  end

  test "slide kiosk assignment only allows directly accessible kiosks and preserves hidden assignments" do
    user_permission = UserPermission.create!(user: @user, permission: @permission)
    user_permission.kiosks << @signage_kiosk

    Current.user = @user

    new_slide = Slide.create!(title: "Restricted Assignment")
    new_slide.kiosk_ids = [@catalog_kiosk.id]
    assert_empty new_slide.kiosk_ids

    existing_slide = Slide.create!(title: "Mixed Assignment")
    existing_slide.kiosks = [@signage_kiosk, @catalog_kiosk]
    existing_slide.kiosk_ids = [@signage_kiosk.id]

    assert_equal [@catalog_kiosk.id, @signage_kiosk.id].sort, existing_slide.kiosk_ids.sort
  ensure
    Current.user = nil
  end

  test "users without manage slides cannot change slides" do
    staff = Permission.find_or_create_by!(name: "staff")
    user_permission = @user.user_permissions.find_by!(permission: staff)
    user_permission.kiosks << @signage_kiosk
    slide = Slide.create!(title: "Signage Slide")
    slide.kiosks << @signage_kiosk

    ability = Ability.new(@user)

    assert ability.cannot?(:create, Slide)
    assert ability.cannot?(:update, slide)
  end

  test "slide managers cannot edit slides shared with inaccessible kiosks" do
    user_permission = UserPermission.create!(user: @user, permission: @permission)
    user_permission.kiosks << @signage_kiosk
    local_slide = Slide.create!(title: "Local Slide")
    local_slide.kiosks << @signage_kiosk
    shared_slide = Slide.create!(title: "Shared Slide")
    shared_slide.kiosks = [@signage_kiosk, @catalog_kiosk]
    fallback = Slide.create!(title: "Global Fallback", fallback: true)

    ability = Ability.new(@user)

    assert ability.can?(:read, local_slide)
    assert ability.can?(:update, local_slide)
    assert ability.can?(:read, shared_slide)
    assert ability.cannot?(:update, shared_slide)
    assert ability.cannot?(:read, fallback)
    assert ability.cannot?(:update, fallback)
  end
end
