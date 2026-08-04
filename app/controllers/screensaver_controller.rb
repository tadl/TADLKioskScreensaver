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

    # Ensure we have a Host record for this hostname
    Host.find_or_create_by!(name: host) if host.present?

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
    KioskStatus.mark!(kiosk: @kiosk, host: host, state: :screensaver) if host.present?

    @slides = ScreensaverSlideDeck.new(kiosk: @kiosk, date: today, random: true).slides
    return render(:empty) if @slides.empty?

    base        = request.base_url
    params_hash = { kiosk: @kiosk.slug, host: host } # host here is the query param
    @exit_url   = Rails.application.routes.url_helpers
                   .exit_screensaver_url(params_hash, host: request.base_url)

    @slide_data = Slide.screensaver_payload(@slides, base)
  rescue ActiveRecord::RecordNotFound
    render :empty, status: :bad_request, layout: false
  end

  # GET  /slides.json?kiosk=<slug>
  # Returns JSON: { slides: [ { url, duration, title }, … ] }
  def slides_json
    kiosk = Kiosk.find_by!(slug: params[:kiosk])
    data = ScreensaverSlideDeck.new(kiosk: kiosk).payload(request.base_url)

    render json: { slides: data }
  rescue ActiveRecord::RecordNotFound
    render json: { slides: [] }, status: :bad_request
  end

  # GET /exit?kiosk=<slug>&host=<hostname>
  def exit
    kiosk_code = params[:kiosk].to_s
    host       = params[:host].to_s.presence

    Host.find_or_create_by!(name: host) if host.present?

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

    kiosk = Kiosk.find_by(slug: kiosk_code)
    if kiosk
      KioskStatus.mark!(kiosk: kiosk, host: host, state: :opac) if host.present?
      redirect_to_catalog(kiosk)
    else
      redirect_to root_path
    end
  end

  # GET /home?kiosk=<slug>&host=<hostname>
  #
  # “Soft” home:
  # - Redirects to the kiosk’s catalog_url
  # - DOES NOT touch KioskSession or KioskStatus (no timer resets)
  def home
    kiosk_code = params[:kiosk].to_s
    host       = params[:host].to_s.presence

    Host.find_or_create_by!(name: host) if host.present?

    kiosk = Kiosk.find_by(slug: kiosk_code)

    if kiosk
      redirect_to_catalog(kiosk)
    else
      redirect_to root_path
    end
  end

  private

  def redirect_to_catalog(kiosk)
    redirect_to catalog_redirect_url(kiosk), allow_other_host: true
  rescue URI::InvalidURIError
    redirect_to root_path
  end

  def catalog_redirect_url(kiosk)
    uri = URI.parse(kiosk.catalog_url.to_s)
    raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.to_s
  end
end
