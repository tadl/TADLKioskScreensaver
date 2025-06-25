# app/models/ability.rb
# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Guest fallback
    user ||= User.new

    # ----------------------------------------------------------------
    # 1) Full-access admins
    # ----------------------------------------------------------------
    if user.admin? || user.can?('admin')
      can :manage, :all
      return
    end

    # ----------------------------------------------------------------
    # 2) Everyone gets read + RailsAdmin access
    # ----------------------------------------------------------------
    can :read, :all
    can :access, :rails_admin   # enter RailsAdmin
    can :dashboard, :all        # view the dashboard

    # ----------------------------------------------------------------
    # 3) Lock down Permission tables
    # ----------------------------------------------------------------
    cannot :manage, [Permission, UserPermission]

    # ----------------------------------------------------------------
    # 4) UserPermission management
    # ----------------------------------------------------------------
    if user.can?('manage_users')
      can :manage, UserPermission
    end

    # ----------------------------------------------------------------
    # 5) Group-based kiosk/slide management
    #
    #    Pull all kiosk_group_ids the user has via user_permissions
    # ----------------------------------------------------------------
    group_ids = user.kiosk_group_ids
    if group_ids.any?
      can :manage, KioskGroup, id: group_ids
      can :manage, Kiosk,       kiosk_group_id: group_ids

      can :manage, Slide do |slide|
        # true if any of the slide’s kiosks lives in a permitted group
        slide.kiosks.any? { |k| group_ids.include?(k.kiosk_group_id) }
      end
    end

    # ----------------------------------------------------------------
    # 6) Legacy flag-based fallbacks (if still used)
    # ----------------------------------------------------------------
    can :manage, Slide      if user.can?('manage_slides')
    can :manage, Kiosk      if user.can?('manage_kiosks')
    can :manage, KioskGroup if user.can?('manage_kiosk_groups')
  end
end
