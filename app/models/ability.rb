# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    allowed_groups = user.kiosk_group_ids

    # 1) Admins get everything
    if user.admin? || user.can?('admin')
      can :manage, :all
      return
    end

    # 2) Everyone else: base read on all
    can :read, :all

    # 3) But no read on permissions or user_permissions unless granted below
    cannot :read, Permission
    cannot :read, UserPermission

    # 4) And no public kiosks unless assigned or given kiosk rights
    cannot :read, Kiosk

    # 5) RailsAdmin UI
    can :access,    :rails_admin
    can :dashboard, :all

    # 6) UserPermission management
    if user.can?('manage_users')
      can :manage, UserPermission
    end

    # 7) Permission management
    if user.can?('manage_permissions')
      can :manage, Permission
    end

    # 8) KioskGroup
    if user.can?('manage_kioskgroups')
      can :manage, KioskGroup
    elsif allowed_groups.any?
      can :read, KioskGroup, id: allowed_groups
    end

    # 9) Kiosk
    if user.can?('manage_kiosks')
      can :manage, Kiosk
    elsif user.can?('manage_slides') && allowed_groups.any?
      can [:read, :update], Kiosk, kiosk_group_id: allowed_groups
    end

    # 10) Slides (within their groups)
    if allowed_groups.any?
      can [:read, :create, :update], Slide
      if user.can?('manage_slides')
        can :destroy, Slide do |slide|
          slide.kiosk_ids.empty?
        end
      end
    end

    # 11) Extra safety: never destroy an in-use slide
    cannot :destroy, Slide do |slide|
      slide.kiosk_ids.any?
    end
  end
end
