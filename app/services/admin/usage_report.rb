# frozen_string_literal: true

class Admin::UsageReport
  attr_reader :date_range, :groups, :selected_group, :sessions

  def initialize(user:, params:, helpers:)
    @date_range = helpers.kiosk_usage_date_range(params[:start], params[:end], helpers.kiosk_usage_presets.fetch("last_30_days"))
    range_start = date_range.begin.beginning_of_day
    range_end = [date_range.end.end_of_day, Time.current].min
    scope = KioskSession.includes(kiosk: :kiosk_group).overlapping(range_start, range_end)
    scope = scope.where(kiosk_code: user.accessible_kiosks.select(:slug)) unless user.admin?
    @groups = KioskGroup.where(id: user.accessible_kiosk_group_ids).order(:name).to_a
    @selected_group = groups.find { |group| group.id.to_s == params[:kiosk_group].to_s }
    scope = scope.where(kiosk_code: selected_group.kiosks.select(:slug)) if selected_group
    @sessions = scope.order(:started_at, :id).to_a
  end

  def grouped
    sessions.group_by { |session| session.kiosk&.kiosk_group }
      .sort_by { |group, entries| [-entries.size, group&.name.to_s] }
  end
end
