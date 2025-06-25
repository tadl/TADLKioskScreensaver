# app/models/ability.rb
# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Guest fallback
    user ||= User.new

    # 1) Full‐access admins
    if user.admin? || user.can?('admin')
      can :manage, :all
      return
    end

    # 2) Read‐only + RailsAdmin access for everyone
    can :read, :all
    can :access, :rails_admin
    can :dashboard, :all

    # 3) Lock down Permissions tables
    cannot :manage, [Permission, UserPermission]

    # 4) UserPermission management (if they have that flag)
    can :manage, UserPermission if user.can?('manage_users')

    # 5) Group‐based kiosk/slide management via SQL conditions
    group_ids = user.kiosk_group_ids
    if group_ids.any?
      # only those specific groups
      can :read, KioskGroup, id: group_ids

      # only kiosks in those groups
      can :manage, Kiosk, kiosk_group_id: group_ids

      # only slides whose kiosks belong to those groups
      can :manage, Slide, kiosks: { kiosk_group_id: group_ids }
    end

    # 6) Legacy flag‐based fallbacks
    can :manage, Slide      if user.can?('manage_slides')
    can :manage, Kiosk      if user.can?('manage_kiosks')
    can :manage, KioskGroup if user.can?('manage_kiosk_groups')
  end
end
