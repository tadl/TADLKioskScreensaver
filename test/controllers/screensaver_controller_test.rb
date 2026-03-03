require "test_helper"

class ScreensaverControllerTest < ActionDispatch::IntegrationTest
  test "root without kiosk renders landing page" do
    get root_url

    assert_response :success
    assert_includes response.body, "Please supply a kiosk code"
  end

  test "unknown kiosk renders empty state with bad request" do
    get root_url, params: { kiosk: "missing-kiosk" }

    assert_response :bad_request
    assert_includes response.body, "Unknown kiosk code"
  end

  test "index with kiosk and host closes an open session and marks screensaver state" do
    kiosk = kiosks(:one)
    host = "kiosk-host-01"
    slide = create_slide_with_image!(
      title: "Open Hours",
      display_seconds: 12,
      start_date: Date.current - 1,
      end_date: Date.current + 1
    )
    kiosk.slides << slide
    session = KioskSession.create!(kiosk_code: kiosk.slug, host: host, started_at: 5.minutes.ago)

    get root_url, params: { kiosk: kiosk.slug, host: host }

    assert_response :success
    assert_predicate Host.find_by(name: host), :present?
    assert_not_nil session.reload.ended_at

    status = KioskStatus.find_by!(kiosk: kiosk, host: host)
    assert_equal "screensaver", status.state
    assert_includes response.body, 'window.kioskCode = "east-bay"'
    assert_includes response.body, 'window.kioskHost = "kiosk-host-01"'
    assert_includes response.body, 'window.location.replace(stickyUrl("/exit"))'
    assert_includes response.body, "Open Hours"
  end

  test "slides json falls back when kiosk has no active slides" do
    kiosk = kiosks(:two)
    fallback = create_slide_with_image!(
      title: "Fallback Slide",
      display_seconds: 20,
      fallback: true,
      start_date: Date.current - 10,
      end_date: Date.current + 10
    )
    expired = create_slide_with_image!(
      title: "Expired Slide",
      display_seconds: 7,
      start_date: Date.current - 10,
      end_date: Date.current - 1
    )
    kiosk.slides << expired

    get "/slides.json", params: { kiosk: kiosk.slug }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [fallback.title], json.fetch("slides").map { |s| s.fetch("title") }
  end

  test "exit creates a session when needed and redirects to the kiosk catalog" do
    kiosk = kiosks(:one)
    host = "catalog-host-02"

    get exit_screensaver_url, params: { kiosk: kiosk.slug, host: host }

    assert_redirected_to kiosk.catalog_url

    session = KioskSession.find_by!(kiosk_code: kiosk.slug, host: host, ended_at: nil)
    assert_predicate session.started_at, :present?

    status = KioskStatus.find_by!(kiosk: kiosk, host: host)
    assert_equal "opac", status.state
  end

  private

  def create_slide_with_image!(title:, display_seconds:, start_date:, end_date:, fallback: false)
    slide = Slide.create!(
      title: title,
      display_seconds: display_seconds,
      start_date: start_date,
      end_date: end_date,
      fallback: fallback
    )
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image bytes"),
      filename: "#{title.parameterize}.jpg",
      content_type: "image/jpeg",
      metadata: { width: 1920, height: 1080 },
      identify: false
    )
    slide.image.attach(blob)
    slide
  end
end
