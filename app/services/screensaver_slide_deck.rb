# frozen_string_literal: true

class ScreensaverSlideDeck
  def initialize(kiosk:, date: Date.current, random: false)
    @kiosk = kiosk
    @date = date
    @random = random
  end

  def slides
    selected = @kiosk.slides.active_on(@date)
    selected = selected.order(Arel.sql("RANDOM()")) if @random
    selected.any? ? selected : Slide.fallbacks
  end

  def payload(base_url)
    Slide.screensaver_payload(slides, base_url)
  end
end
