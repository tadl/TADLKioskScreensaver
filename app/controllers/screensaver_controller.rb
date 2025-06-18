# app/controllers/screensaver_controller.rb
class ScreensaverController < ApplicationController
  # Don’t wrap this view in the application layout—render it “standalone”
  layout false

  def index
    @kiosk = Kiosk.find_by!(slug: params[:kiosk])
    today  = Date.current

    # Fetch only slides valid for today, and randomize the order
    @slides = @kiosk.slides
                    .where("start_date IS NULL OR start_date <= ?", today)
                    .where("end_date   IS NULL OR end_date   >= ?", today)
                    .order(Arel.sql("RANDOM()"))

    @exit_url = @kiosk.catalog_url
  rescue ActiveRecord::RecordNotFound
    render plain: "Unknown kiosk", status: :bad_request
  end
end

