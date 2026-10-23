require "application_system_test_case"

if ENV["CAPTURE_ADMIN_HELP"] == "1"
  database = ActiveRecord::Base.connection_db_config
  unless Rails.env.test? && database.database.end_with?("_test") && %w[127.0.0.1 localhost ::1].include?(database.host)
    abort "Help screenshots must use an isolated local test database."
  end
end

class AdminHelpTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1440, 1100]

  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(1440, 1100)
    @image_dir = Dir.mktmpdir("admin-slide-help")
    @image_path = File.join(@image_dir, "reading-together.png")
    prepare_image
    @kiosks = ["Children’s room", "Lobby", "Meeting room"].map.with_index do |name, index|
      Kiosk.create!(name: "Sample Library · #{name}", slug: "guide-kiosk-#{index}", catalog_url: "https://catalog.example.com/guide-#{index}")
    end
    actor = users(:two)
    actor.update!(name: "Guide Example", image_url: nil)
    role = actor.user_permissions.create!(permission: Permission.find_or_create_by!(name: "manage_slides"))
    role.kiosks = @kiosks
    auth = OmniAuth::AuthHash.new(provider: "test", uid: "synthetic-help", info: { email: actor.email, name: actor.name })
    Rails.application.env_config["omniauth.auth"] = auth
    stub_const(Object, :GOOGLE_DOMAIN, "example.com") { visit "/auth/test/callback" }
    assert_current_path admin_root_path
    Rails.application.env_config.delete("omniauth.auth")
  end

  teardown do
    Rails.application.env_config.delete("omniauth.auth")
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(1440, 1100)
    FileUtils.remove_entry(@image_dir) if @image_dir
  end

  test "staff can add one slide to multiple kiosks while filtering choices" do
    existing = Slide.new(title: "Reading together", display_seconds: 10)
    blob = File.open(@image_path) do |image|
      ActiveStorage::Blob.create_and_upload!(io: image, filename: "reading-together.png",
        content_type: "image/png", metadata: { width: 1920, height: 1080 }, identify: false)
    end
    existing.image.attach(blob)
    existing.kiosks = [@kiosks.first]
    existing.save!
    visit admin_slides_path
    assert_text "Reading together"
    capture_help_image("slide-list", ".admin-main")

    click_link "+ Add slide"
    assert_current_path new_admin_slide_path
    fill_in "Title", with: "Family reading night"
    attach_file "Image", @image_path
    fill_in "Display time in seconds", with: "15"
    capture_help_image("slide-details", ".admin-record-form")

    fill_in "Filter assign to kiosks", with: "Children"
    check @kiosks.first.name
    fill_in "Filter assign to kiosks", with: "Lobby"
    check @kiosks.second.name
    fill_in "Filter assign to kiosks", with: ""
    assert_checked_field @kiosks.first.name
    assert_checked_field @kiosks.second.name
    assert_unchecked_field @kiosks.third.name
    capture_help_image("kiosk-assignments", ".admin-form-grid > section:last-child")

    click_button "Save slide"
    assert_current_path %r{\A/admin/slides/\d+\z}
    slide = Slide.find_by!(title: "Family reading night")
    assert_current_path admin_slide_path(slide)
    assert_text "Slide saved."
    assert_text "15 seconds"
    assert_equal @kiosks.first(2).map(&:id).sort, slide.reload.kiosk_ids.sort
    assert_link @kiosks.first.name
    assert_link @kiosks.second.name
    assert_no_link @kiosks.third.name
    capture_help_image("slide-saved", ".admin-main")
  end

  test "the account menu opens a readable illustrated help page on desktop and mobile" do
    find(".admin-account-toggle").click
    click_link "Help"
    assert_current_path admin_help_path
    assert_selector "h1", text: "Help"
    assert_selector "h2", text: "How to add a slide to one or more kiosks"
    assert_selector ".admin-help figure img", count: 4
    all(".admin-help figure img").each do |picture|
      page.scroll_to picture, align: :center
      loaded = Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
        picture.native.property("complete") && picture.native.property("naturalWidth").positive?
      end
      assert loaded
      assert_equal picture[:src], picture.find(:xpath, "..").native.attribute("href")
    end
    page.execute_script("window.scrollTo(0, 0)")
    page.save_screenshot Rails.root.join("tmp/screenshots/admin-help-desktop.png")
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: false)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot Rails.root.join("tmp/screenshots/admin-help-mobile.png")
  end

  private

  def capture_help_image(name, selector)
    return unless ENV["CAPTURE_ADMIN_HELP"] == "1"

    # Capture only the application content, using the synthetic account and
    # records above. Normal test runs never rewrite the published screenshots.
    destination = Rails.root.join("app/assets/images/help")
    FileUtils.mkdir_p(destination)
    all("#{selector} img", visible: :all).each do |picture|
      page.scroll_to picture, align: :center
      Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
        picture.native.property("complete") && picture.native.property("naturalWidth").positive?
      end
    end
    find(selector).native.save_screenshot(destination.join("#{name}.png"))
  end

  def prepare_image
    if ENV["CAPTURE_ADMIN_HELP"] == "1"
      # A code-drawn sample poster, with no real event or patron information.
      source = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
          <rect width="1920" height="1080" fill="#0b2f57"/>
          <circle cx="1770" cy="140" r="350" fill="#49688e"/>
          <rect x="110" y="130" width="16" height="820" rx="8" fill="#f4cb83"/>
          <g font-family="sans-serif" fill="white">
            <text x="180" y="270" font-size="48" letter-spacing="8">EXAMPLE LIBRARY</text>
            <text x="180" y="485" font-size="132" font-weight="bold">Reading</text>
            <text x="180" y="640" font-size="132" font-weight="bold">together.</text>
            <text x="190" y="795" font-size="48" fill="#e3ebf5">Stories, activities, and a little imagination.</text>
            <text x="190" y="925" font-size="34" fill="#f4cb83">DEMONSTRATION SLIDE</text>
          </g>
        </svg>
      SVG
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false)
      visit "data:image/svg+xml;charset=utf-8,#{ERB::Util.url_encode(source)}"
      assert_selector "svg"
      page.driver.browser.save_screenshot(@image_path)
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    else
      MiniMagick.convert { |command| command.size "1920x1080"; command << "xc:#0b2f57"; command << @image_path }
    end
  end
end
