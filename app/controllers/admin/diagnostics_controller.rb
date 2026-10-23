# frozen_string_literal: true

# Inherit the existing host-to-kiosk authorization and JSON endpoint's access
# rules rather than creating a second policy for the HTML presentation.
class Admin::DiagnosticsController < Admin::KioskHostsController
  layout "admin"

  def show
    @host = requested_host
    @details = Admin::KioskHostDetails.new(@host).as_json
  end

  private

  def requested_host = params[:hostname].to_s.strip
end
