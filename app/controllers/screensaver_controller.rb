# app/controllers/screensaver_controller.rb
class ScreensaverController < ApplicationController
  # Don’t wrap these views in the application layout—render them “standalone”
  layout false

  # GET  /?kiosk=<slug>&host=<hostname>
  def index
    # If no kiosk param, render the generic landing page
    return render(:landing) if params[:kiosk].blank?

    # End session for this kiosk/host if both present
    if params[:host].present?
      session = KioskSession.where(
        kiosk_code: params[:kiosk],
        host: params[:host],
        ended_at: nil
      ).order(started_at: :desc).first

      if session
        session.update!(ended_at: Time.zone.now)
      end
    end

    # Look up the kiosk or 400
    @kiosk = Kiosk.find_by!(slug: params[:kiosk])
    today  = Date.current

    # Grab slides valid for today, in random order
    active_slides = @kiosk.slides
      .where("start_date IS NULL OR start_date <= ?", today)
      .where("end_date   IS NULL OR end_date   >= ?", today)
      .order(Arel.sql("RANDOM()"))

    @slides = active_slides.any? ? active_slides : Slide.fallbacks
    return render(:empty) if @slides.empty?

    base      = request.base_url
    @exit_url = Rails.application.routes.url_helpers.exit_screensaver_url(
                  kiosk: @kiosk.slug,
                  host: params[:host], # <-- Pass through host!
                  host: base
                )

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
    kiosk_code = params[:kiosk]
    host = params[:host]

    # Start a new session if both kiosk and host present and no open session
    if kiosk_code.present? && host.present?
      open_session = KioskSession.where(
        kiosk_code: kiosk_code,
        host: host,
        ended_at: nil
      ).order(started_at: :desc).first

      unless open_session
        KioskSession.create!(
          kiosk_code: kiosk_code,
          host: host,
          started_at: Time.zone.now
        )
      end
    end

    kiosk = Kiosk.find_by(slug: kiosk_code)
    if kiosk
      redirect_to kiosk.catalog_url, allow_other_host: true
    else
      redirect_to root_path
    end
  end
end
