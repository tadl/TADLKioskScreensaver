# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    allowed_kiosk_ids = user.accessible_kiosk_ids
    allowed_group_ids = user.accessible_kiosk_group_ids

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
    elsif user.can?('manage_slides') && allowed_kiosk_ids.any?
      can [:read, :update], Kiosk, id: allowed_kiosk_ids
    end

    # 6) Slides. Shared/global slides remain admin-controlled because changing
    # their content would also change kiosks outside the user's scope.
    if user.can?('manage_slides') && allowed_kiosk_ids.any?
      can :create, Slide
      can :read, Slide, id: user.readable_slide_ids
      can :update, Slide, id: user.editable_slide_ids
    end
  end
end
