# app/controllers/screensaver_controller.rb
class ScreensaverController < ApplicationController
  # Don’t wrap these views in the application layout—render them “standalone”
  layout false

  # GET  /?kiosk=<slug>
  def index
    # If no kiosk param, render the generic landing page
    return render(:landing) if params[:kiosk].blank?

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

    @exit_url = @kiosk.catalog_url

    # Build an array of slide data with URLs, durations, and titles
    base = request.base_url
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
end
