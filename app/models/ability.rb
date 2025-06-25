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
    can :access, :rails_admin   # allows entering RailsAdmin
    can :dashboard, :all        # allows viewing the dashboard

    # ----------------------------------------------------------------
    # 3) Lock down your permission tables
    # ----------------------------------------------------------------
    cannot :manage, [Permission, UserPermission]

    # ----------------------------------------------------------------
    # 4) “User” management via UserPermission flags
    # ----------------------------------------------------------------
    if user.can?('manage_users')
      can :manage, User
      can :manage, UserPermission
    end

    # ----------------------------------------------------------------
    # 5) Group-based kiosk/slide management
    #
    #    We pull the kiosk_group_ids from the user’s UserPermission
    # ----------------------------------------------------------------
    if (up = user.user_permission)
      group_ids = up.kiosk_group_ids

      can :manage, KioskGroup, id: group_ids
      can :manage, Kiosk,        kiosk_group_id: group_ids

      can :manage, Slide do |slide|
        # any of the slide’s kiosks belongs to one of those groups?
        slide.kiosks.any? { |k| group_ids.include?(k.kiosk_group_id) }
      end
    end

    # ----------------------------------------------------------------
    # 6) Fallback “old” flags (if you still use them)
    # ----------------------------------------------------------------
    can :manage, Slide       if user.can?('manage_slides')
    can :manage, Kiosk       if user.can?('manage_kiosks')
    can :manage, KioskGroup  if user.can?('manage_kiosk_groups')
  end
end
