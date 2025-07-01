# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    allowed_group_ids = user.kiosk_group_ids

    # 1) Super-admins get everything
    if user.admin? || user.can?('admin')
      can :manage, :all
      return
    end

    # 2) RailsAdmin itself
    can :access,    :rails_admin
    can :read,      :dashboard

    # 3) UserPermissions & Permissions
    if user.can?('manage_users')
      can :manage, UserPermission
      can :read,   Permission
    end

    # 4) KioskGroups
    if user.can?('manage_kioskgroups')
      can :manage, KioskGroup
    elsif allowed_group_ids.any?
      can :read,   KioskGroup, id: allowed_group_ids
    end

    # 5) Kiosks
    if user.can?('manage_kiosks')
      can :manage, Kiosk
    elsif user.can?('manage_slides') && allowed_group_ids.any?
      can [:read, :update], Kiosk, kiosk_group_id: allowed_group_ids
    end

    # 6) Slides
    if allowed_group_ids.any?
      can [:read, :create, :update], Slide
      can :destroy, Slide do |slide|
        user.can?('manage_slides') && slide.kiosk_ids.empty?
      end
    end

    # 7) Never destroy an in-use slide
    cannot :destroy, Slide do |slide|
      slide.kiosk_ids.any?
    end
  end
end
