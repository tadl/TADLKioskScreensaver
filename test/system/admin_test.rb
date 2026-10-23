require "application_system_test_case"

class AdminTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1440, 1100]

  setup do
    @image = Tempfile.new(["admin-slide", ".png"])
    MiniMagick.convert { |command| command.size "1920x1080"; command << "xc:#173c36"; command << @image.path }
    sign_in(users(:one))
  end

  teardown { @image&.close! }

  test "account menu supports keyboard dismissal, outside clicks and sign out" do
    trigger = find(".admin-account-toggle")
    assert_no_button "Sign out"
    trigger.send_keys(:enter)
    assert_selector ".admin-account[open]"
    within ".admin-account-panel" do
      assert_text "admin@example.com"
      assert_button "Sign out"
    end
    page.save_screenshot Rails.root.join("tmp/screenshots/admin-account-menu.png")
    page.send_keys(:escape)
    assert_no_selector ".admin-account[open]"
    assert_equal "admin-account-toggle", page.evaluate_script("document.activeElement.className")

    trigger.click
    find("h1").click
    assert_no_selector ".admin-account[open]"
    trigger.click
    click_button "Sign out"
    assert_current_path root_path
    visit admin_root_path
    assert_current_path login_path
  end

  test "a failed Google avatar leaves a usable initials menu button" do
    avatar_url = "https://lh3.googleusercontent.com/synthetic-avatar.png"
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [avatar_url])
    users(:one).update!(image_url: avatar_url)
    visit admin_root_path
    assert_selector "img.admin-avatar-image[hidden]", visible: false
    assert_equal avatar_url, find("img.admin-avatar-image", visible: false)[:src]
    assert_selector ".admin-avatar", text: "A"
    find(".admin-account-toggle").click
    assert_button "Sign out"
  ensure
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
  end

  test "staff can upload, assign, edit and delete a slide" do
    visit new_admin_slide_path
    fill_in "Title", with: "Local testing campaign"
    attach_file "Image", @image.path
    check "East Bay Branch"
    click_button "Save slide"
    assert_current_path %r{\A/admin/slides/\d+\z}
    slide = Slide.find_by!(title: "Local testing campaign")
    assert_text "Slide saved."
    assert_text "Local testing campaign"
    click_link "Edit slide"
    assert_current_path edit_admin_slide_path(slide)
    fill_in "Display time in seconds", with: "18"
    click_button "Save slide"
    assert_current_path admin_slide_path(slide)
    assert_text "18 seconds"
    accept_confirm { click_button "Delete" }
    assert_current_path admin_slides_path
    assert_text "Slide deleted."
    assert_not Slide.exists?(title: "Local testing campaign")
  end

  test "every resource screen renders and the mobile navigation works" do
    [admin_slides_path, admin_kiosks_path, admin_kiosk_groups_path, admin_hosts_path,
     admin_permissions_path, admin_user_permissions_path].each do |path|
      visit path
      assert_selector "h1"
      assert_selector ".admin-panel"
    end
    [new_admin_kiosk_path, new_admin_kiosk_group_path, new_admin_host_path, new_admin_permission_path,
     edit_admin_user_permission_path(user_permissions(:two))].each do |path|
      visit path
      assert_selector ".admin-record-form"
    end
    visit "/admin/user_permissions/new"
    assert_text "404"
    visit "/admin/slide"
    assert_current_path admin_slides_path
    visit "/admin/slide/#{slides(:one).id}/edit"
    assert_current_path edit_admin_slide_path(slides(:one))
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_root_path
    find(".admin-mobile-nav summary").click
    within ".admin-mobile-nav" do
      click_link "Slides"
    end
    assert_current_path admin_slides_path
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot Rails.root.join("tmp/screenshots/admin-mobile.png")
  ensure
    page.driver.browser.manage.window.resize_to(1440, 1100)
  end

  test "dashboard charts and diagnostics work and escape log content" do
    kiosk = kiosks(:one)
    KioskStatus.mark!(kiosk: kiosk, host: "demo-host.example.com", state: :opac)
    KioskSession.create!(kiosk_code: kiosk.slug, host: "demo-host.example.com", started_at: 1.hour.ago, ended_at: 10.minutes.ago)
    KioskLog.create!(kiosk_id: "demo-host.example.com", occurred_at: Time.current, level: "warn", message: "<img src=x onerror=window.logInjected=true>")
    visit admin_root_path
    assert_selector "canvas"
    assert page.evaluate_script("Chart.getChart(document.querySelector('canvas')) !== undefined")
    page.save_screenshot Rails.root.join("tmp/screenshots/admin-overview.png")
    click_link "demo-host.example.com"
    assert_text /Host diagnostics/i
    assert_text "<img src=x onerror=window.logInjected=true>"
    assert_nil page.evaluate_script("window.logInjected")
    click_link "Overview", match: :first
    assert_selector "canvas"
    assert page.evaluate_script("Chart.getChart(document.querySelector('canvas')) !== undefined")
  end

  test "selection controls, assignment filtering and confirmation work" do
    visit admin_slides_path
    find('input[aria-label="Select all records on this page"]').check
    assert_selector '[data-selection-target="count"]', text: "2"
    dismiss_confirm { click_button "Delete selected" }
    assert_equal 2, Slide.count
    visit new_admin_slide_path
    fill_in "Filter assign to kiosks", with: "East Bay"
    assert_selector ".admin-assignment-option", text: "East Bay Branch"
    assert_no_selector ".admin-assignment-option", text: "Main Library"
  end

  private

  def sign_in(user)
    auth = OmniAuth::AuthHash.new(provider: "test", uid: "synthetic-#{user.id}", info: { email: user.email, name: user.name })
    Rails.application.env_config["omniauth.auth"] = auth
    stub_const(Object, :GOOGLE_DOMAIN, "example.com") { visit "/auth/test/callback" }
    assert_current_path admin_root_path
  ensure
    Rails.application.env_config.delete("omniauth.auth")
  end
end
