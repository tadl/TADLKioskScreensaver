# frozen_string_literal: true

class Admin::DashboardController < Admin::BaseController
  def index
    authorize! :read, :dashboard
    @report = Admin::UsageReport.new(user: current_user, params: params, helpers: helpers)
    # HTML includes the report tables; polling only needs a database count.
    @report.sessions if request.format.html?
    @status_snapshot = status_snapshot
    @active_tab = params[:tab] == "stats" ? "stats" : "status"

    respond_to do |format|
      format.html
      format.json { render json: @status_snapshot }
    end
  end

  private

  def status_snapshot
    now = Time.current
    kiosks = current_user.accessible_kiosks
    statuses = KioskStatus.includes(kiosk: :kiosk_group)
      .where(kiosk_id: kiosks.select(:id)).order(:host).to_a
    groups = statuses.group_by(&:kiosk)
      .sort_by { |kiosk, _| [kiosk.kiosk_group&.name.to_s, kiosk.name] }

    {
      updated_at: now.iso8601,
      metrics: { kiosks: kiosks.count, in_use: statuses.count(&:opac?),
        screensaver: statuses.count(&:screensaver?), usage_sessions: @report.session_count },
      fallback_missing: Slide.fallbacks.with_image.active_on(Date.current).none?,
      kiosks: groups.map do |kiosk, hosts|
        { name: kiosk.name, group: kiosk.kiosk_group&.name || "No group",
          hosts: hosts.map do |status|
            { id: status.id, host: status.host, state: status.state,
              duration: status.state_duration_label(now),
              url: admin_diagnostic_path(hostname: status.host) }
          end }
      end
    }
  end
end
