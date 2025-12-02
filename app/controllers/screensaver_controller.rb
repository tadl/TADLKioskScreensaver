# frozen_string_literal: true

class ScreensaverController < ApplicationController
  # Don’t wrap these views in the application layout—render them “standalone”
  layout false

  # GET  /?kiosk=<slug>&host=<hostname>
  def index
    # If no kiosk param, render the generic landing page
    return render(:landing) if params[:kiosk].blank?

    kiosk_code = params[:kiosk].to_s
    host       = params[:host].to_s.presence

    # End session for this kiosk/host if both present
    if host.present?
      session = KioskSession.where(
        kiosk_code: kiosk_code,
        host:       host,
        ended_at:   nil
      ).order(started_at: :desc).first
      session&.update!(ended_at: Time.zone.now)
    end

    # Look up the kiosk or 400
    @kiosk = Kiosk.find_by!(slug: kiosk_code)
    today  = Date.current

    # Record state: entering screensaver
    upsert_kiosk_status(@kiosk, host, :screensaver) if host.present?

    # Grab slides valid for today, in random order
    active_slides = @kiosk.slides
      .where("start_date IS NULL OR start_date <= ?", today)
      .where("end_date   IS NULL OR end_date   >= ?", today)
      .order(Arel.sql("RANDOM()"))

    @slides = active_slides.any? ? active_slides : Slide.fallbacks
    return render(:empty) if @slides.empty?

    base        = request.base_url
    params_hash = { kiosk: @kiosk.slug, host: host } # host here is the query param
    @exit_url   = Rails.application.routes.url_helpers
                   .exit_screensaver_url(params_hash, host: request.base_url)

    # Build an array of slide data with URLs, durations, and titles
    @slide_data = @slides.map do |s|
      {
        url:      Rails.application.routes.url_helpers.rails_blob_url(s.image, host: base),
        duration: s.display_seconds,
        title:    s.title
      }
    end
  rescue ActiveRecord::RecordNotFound
    render :empty, status: :bad_request, layout: false
  end

  # GET  /slides.json?kiosk=<slug>
  # Returns JSON: { slides: [ { url, duration, title }, … ] }
  def slides_json
    kiosk = Kiosk.find_by!(slug: params[:kiosk])
    today = Date.current

    active = kiosk.slides
      .where("start_date IS NULL OR start_date <= ?", today)
      .where("end_date   IS NULL OR end_date   >= ?", today)

    slides = active.any? ? active : Slide.fallbacks

    base = request.base_url
    data = slides.map do |s|
      {
        url:      Rails.application.routes.url_helpers.rails_blob_url(s.image, host: base),
        duration: s.display_seconds,
        title:    s.title
      }
    end

    render json: { slides: data }
  rescue ActiveRecord::RecordNotFound
    render json: { slides: [] }, status: :bad_request
  end

  # GET /exit?kiosk=<slug>&host=<hostname>
  def exit
    kiosk_code = params[:kiosk].to_s
    host       = params[:host].to_s.presence

    # Start a new session if both kiosk and host present and no open session
    if kiosk_code.present? && host.present?
      open_session = KioskSession.where(
        kiosk_code: kiosk_code,
        host:       host,
        ended_at:   nil
      ).order(started_at: :desc).first

      unless open_session
        KioskSession.create!(
          kiosk_code: kiosk_code,
          host:       host,
          started_at: Time.zone.now
        )
      end
    end

    # Record state: exiting to OPAC (active)
    if host.present? && kiosk_code.present?
      if (kiosk = Kiosk.find_by(slug: kiosk_code))
        upsert_kiosk_status(kiosk, host, :opac)
      end
    end

    kiosk = Kiosk.find_by(slug: kiosk_code)
    if kiosk
      redirect_to kiosk.catalog_url, allow_other_host: true
    else
      redirect_to root_path
    end
  end

  private

  # For dashboards:
  # - If state changes (screensaver -> opac or vice versa), update state + timestamp.
  # - If we *re-enter* the screensaver with the same state (e.g., reboot straight into it),
  #   bump state_changed_at anyway so the idle clock restarts.
  def upsert_kiosk_status(kiosk, host, new_state)
    return unless kiosk && host.present?

    now           = Time.zone.now
    new_state_str = new_state.to_s
    ks            = KioskStatus.find_or_initialize_by(kiosk: kiosk, host: host)

    if ks.new_record? || ks.state != new_state_str
      ks.state            = new_state_str
      ks.state_changed_at = now
    elsif new_state_str == "screensaver"
      # Same state but a fresh screensaver load (e.g., reboot) — treat as new “idle since”
      ks.state_changed_at = now
    end

    ks.save! if ks.changed?
  rescue => e
    Rails.logger.warn(
      "[KioskStatus] upsert failed for kiosk=#{kiosk&.id} host=#{host} state=#{new_state}: " \
      "#{e.class}: #{e.message}"
    )
  end
end
