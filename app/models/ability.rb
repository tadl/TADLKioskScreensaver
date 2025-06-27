# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    allowed_groups = user.kiosk_group_ids

    # never destroy an in‐use slide
    cannot :destroy, Slide do |slide|
      slide.kiosk_ids.any?
    end

    if user.admin? || user.can?('admin')
      can :manage, :all
    else
      can :read,      :all
      cannot :read, Kiosk

      can :access,    :rails_admin
      can :dashboard, :all

      cannot :manage, [Permission, UserPermission]
      can :manage, UserPermission if user.can?('manage_users')

      if allowed_groups.any?
        can :read,    KioskGroup, id: allowed_groups
        can [:read, :create, :update], Kiosk, kiosk_group_id: allowed_groups

        # Slide: anyone in a group can read/create/update all slides...
        can [:read, :create, :update], Slide
        if user.can?('manage_slides')
          can :destroy, Slide do |slide|
            slide.kiosk_ids.empty?
          end
        end
      end

      can :manage, Kiosk      if user.can?('manage_kiosks')
      can :manage, KioskGroup if user.can?('manage_kiosk_groups')
    end
  end
end
