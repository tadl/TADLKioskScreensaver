require "application_system_test_case"

class ScreensaverTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]

  setup do
    # Capture the real refresh callback so these tests do not wait thirty minutes.
    @refresh_hook = page.driver.browser.execute_cdp(
      "Page.addScriptToEvaluateOnNewDocument",
      source: <<~JS
        const originalSetInterval = window.setInterval.bind(window);
        window.setInterval = (callback, delay, ...args) => {
          if (delay === 30 * 60 * 1000) window.testRefreshSlides = callback;
          return originalSetInterval(callback, delay, ...args);
        };
      JS
    ).fetch("identifier")

    visit "/login"
    @kiosk = kiosks(:one)
    @kiosk.update!(catalog_url: URI.join(page.current_url, "/login").to_s)
    @screensaver_path = "/?kiosk=#{@kiosk.slug}&host=playback-test-host"
  end

  teardown do
    page.driver.browser.execute_cdp(
      "Page.removeScriptToEvaluateOnNewDocument", identifier: @refresh_hook
    ) if @refresh_hook
  end

  test "an empty screensaver wakes and records usage" do
    visit @screensaver_path
    assert_text "No slides scheduled"

    page.execute_script('window.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }))')

    assert_current_path "/login"
    assert KioskSession.exists?(kiosk_code: @kiosk.slug, host: "playback-test-host", ended_at: nil)
  end

  test "an empty screensaver picks up newly assigned slides" do
    visit @screensaver_path
    assert_text "No slides scheduled"
    @kiosk.slides << create_slide_with_image!(title: "New Content")

    page.execute_script("window.testRefreshSlides()")

    # Wait for the new document before querying elements from the refreshed page.
    assert_title "Kiosk Screensaver", exact: true

    assert_selector "#screensaver-image[alt='New Content']"
    assert_no_text "No slides scheduled"
  end

  test "a successful empty refresh stops showing removed slides" do
    @kiosk.slides << create_slide_with_image!(title: "Removed Content")
    visit @screensaver_path
    assert_selector "#screensaver-image[alt='Removed Content']"
    @kiosk.slides.clear

    page.execute_script("window.testRefreshSlides()")

    assert_title "TADL Kiosk Screensaver App", exact: true

    assert_text "No slides scheduled"
    assert_no_selector "#screensaver-image"
  end
end
