# app/models/ability.rb
# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # guest fallback
    user ||= User.new

    # full admin via boolean OR via the 'admin' permission
    if user.admin? || user.can?('admin')
      can :manage, :all
      return
    end

    # everyone can read all resources
    can :read, :all

    # slide management
    can :manage, Slide if user.can?('manage_slides')

    # kiosk management
    can :manage, Kiosk if user.can?('manage_kiosks')

    # kiosk‐group management
    can :manage, KioskGroup if user.can?('manage_kiosk_groups')

    # user management (e.g. invite/edit/remove)
    can :manage, User if user.can?('manage_users')

    # lock down your permission tables
    cannot :manage, [Permission, UserPermission]
  end
end

