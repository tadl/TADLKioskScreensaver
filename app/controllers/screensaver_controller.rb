# app/controllers/screensaver_controller.rb
class ScreensaverController < ApplicationController
  # Don’t wrap these views in the application layout—render them “standalone”
  layout false

  def index
    # first, if no kiosk param at all, show the generic landing
    return render(:landing) if params[:kiosk].blank?

    # look up the kiosk or 400 if it doesn't exist
    @kiosk = Kiosk.find_by!(slug: params[:kiosk])
    today  = Date.current

    # grab only slides valid for today, in random order
    active_slides = @kiosk.slides
                    .where("start_date IS NULL OR start_date <= ?", today)
                    .where("end_date   IS NULL OR end_date   >= ?", today)
                    .order(Arel.sql("RANDOM()"))

    @slides = active_slides.any? ? active_slides : Slide.fallbacks

    # if we have a kiosk param, but zero slides → show the “empty” full‐page screen
    return render(:empty) if @slides.empty?

    # otherwise fall through to index.html.erb, which will run the screensaver
    @exit_url = @kiosk.catalog_url
  rescue ActiveRecord::RecordNotFound
    render :empty, status: :bad_request
  end
end
