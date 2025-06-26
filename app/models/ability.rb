# app/models/ability.rb
# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Guest fallback
    user ||= User.new

    # 1) Always forbid deleting a slide that's assigned to any kiosk
    cannot :destroy, Slide do |slide|
      slide.kiosk_ids.any?
    end

    if user.admin? || user.can?('admin')
      # 2) Admins get full access (except delete on in-use slides)
      can :manage, :all
    else
      # 3) All non-admins: basic read + RailsAdmin access
      can :read,      :all
      can :access,    :rails_admin
      can :dashboard, :all

      # 4) Lock down permissions tables
      cannot :manage, [Permission, UserPermission]

      # 5) Allow managing user permissions if flagged
      can :manage, UserPermission if user.can?('manage_users')

      # 6) Group-based kiosk/slide permissions
      group_ids = user.kiosk_group_ids
      if group_ids.any?
        # can view their kiosk groups
        can :read,    KioskGroup, id: group_ids
        # can manage kiosks in those groups
        can :manage,  Kiosk,      kiosk_group_id: group_ids
        # can read/create/update slides in those kiosks
        can [:read, :create, :update], Slide, kiosks: { kiosk_group_id: group_ids }
      end

      # 7) Legacy flag fallbacks for Kiosk and KioskGroup
      can :manage, Kiosk      if user.can?('manage_kiosks')
      can :manage, KioskGroup if user.can?('manage_kiosk_groups')
    end
  end
end

