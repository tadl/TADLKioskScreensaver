# frozen_string_literal: true

class Admin::DashboardController < Admin::BaseController
  def index
    authorize! :read, :dashboard
    @kiosks = current_user.accessible_kiosks
    @statuses = KioskStatus.includes(kiosk: :kiosk_group).where(kiosk_id: @kiosks.select(:id)).order(:host).to_a
    @status_groups = @statuses.group_by(&:kiosk).sort_by { |kiosk, _| [kiosk.kiosk_group&.name.to_s, kiosk.name] }
    @report = Admin::UsageReport.new(user: current_user, params: params, helpers: helpers)
    @fallback_missing = Slide.fallbacks.with_image.active_on(Date.current).none?
  end
end
