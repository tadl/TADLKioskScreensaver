# frozen_string_literal: true
class Ability
  include CanCan::Ability

  def initialize(user)
    # only admins can manage kiosks & groups
    if user&.admin?
      can :manage, :all
    else
      # non-admin users can only read and assign slides
      can [:read, :update], Kiosk       # only slide assignments in the edit form
      can [:read, :update], Slide
    end
  end
end

