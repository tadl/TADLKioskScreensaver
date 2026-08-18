# frozen_string_literal: true

class ScreensaverController < ApplicationController
  # Don’t wrap these views in the application layout—render them “standalone”
  layout false

  # GET  /?kiosk=<slug>&host=<hostname>
  def index
    # If no kiosk param, render the generic landing page
    return render(:landing) if params[:kiosk].blank?

    @kiosk = Kiosk.find_by!(slug: params[:kiosk].to_s)
    host = validated_host

    Host.find_or_create_by!(name: host) if host.present?

    if host.present?
      now = Time.zone.now
      KioskSession.close_stale!(now: now, kiosk_code: @kiosk.slug, host: host)
      KioskSession.where(
        kiosk_code: @kiosk.slug,
        host:       host,
        ended_at:   nil
      ).update_all(ended_at: now, updated_at: now)
    end

    today  = Date.current

    # Record state: entering screensaver
    KioskStatus.mark!(kiosk: @kiosk, host: host, state: :screensaver) if host.present?

    @slides = ScreensaverSlideDeck.new(kiosk: @kiosk, date: today, random: true).slides
    return render(:empty) if @slides.empty?

    @slide_data = Slide.screensaver_payload(@slides, request.base_url)
  rescue ActiveRecord::RecordNotFound, ActionController::BadRequest
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
    kiosk = Kiosk.find_by(slug: params[:kiosk].to_s)
    return redirect_to(root_path) unless kiosk

    host = validated_host

    Host.find_or_create_by!(name: host) if host.present?

    if host.present?
      now = Time.zone.now
      KioskSession.close_stale!(now: now, kiosk_code: kiosk.slug, host: host)
      KioskSession.find_or_create_by!(
        kiosk_code: kiosk.slug,
        host: host,
        ended_at: nil
      ) do |kiosk_session|
        kiosk_session.started_at = now
      end
    end

    KioskStatus.mark!(kiosk: kiosk, host: host, state: :opac) if host.present?
    redirect_to_catalog(kiosk)
  rescue ActionController::BadRequest
    head :bad_request
  end

  # GET /home?kiosk=<slug>&host=<hostname>
  #
  # “Soft” home:
  # - Redirects to the kiosk’s catalog_url
  # - DOES NOT touch KioskSession or KioskStatus (no timer resets)
  def home
    kiosk = Kiosk.find_by(slug: params[:kiosk].to_s)
    return redirect_to(root_path) unless kiosk

    host = validated_host

    Host.find_or_create_by!(name: host) if host.present?
    redirect_to_catalog(kiosk)
  rescue ActionController::BadRequest
    head :bad_request
  end

  private

  def validated_host
    host = params[:host].to_s.strip.presence
    return if host.nil?
    return host if host.length <= 253 && Host::NAME_FORMAT.match?(host)

    raise ActionController::BadRequest, "invalid host"
  end

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
