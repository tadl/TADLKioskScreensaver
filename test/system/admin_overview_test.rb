require "application_system_test_case"

class AdminOverviewTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1440, 1000]

  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    @window_size = page.driver.browser.manage.window.size
    page.driver.browser.manage.window.resize_to(1440, 1000)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [{ name: "prefers-reduced-motion", value: "reduce" }])
    @refresh_hook = page.driver.browser.execute_cdp(
      "Page.addScriptToEvaluateOnNewDocument",
      source: <<~JS
        const nativeInterval = window.setInterval.bind(window);
        window.setInterval = (callback, delay, ...args) => {
          if (delay === 30000) window.testOverviewRefresh = callback;
          return nativeInterval(callback, delay, ...args);
        };
      JS
    ).fetch("identifier")
    user = users(:one)
    Rails.application.env_config["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: "test", uid: "synthetic-overview", info: { email: user.email, name: user.name }
    )
    stub_const(Object, :GOOGLE_DOMAIN, "example.com") { visit "/auth/test/callback" }
    assert_current_path admin_root_path
    Rails.application.env_config.delete("omniauth.auth")
  end

  teardown do
    Rails.application.env_config.delete("omniauth.auth")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(@window_size.width, @window_size.height)
    page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @refresh_hook) if @refresh_hook
  end

  test "compact status fits a busy desktop and tabs work with keyboard and filters" do
    group = KioskGroup.create!(name: "Example Library", slug: "example")
    kiosk = kiosks(:one)
    kiosk.update!(name: "Main library", kiosk_group: group)
    18.times do |index|
      KioskStatus.mark!(kiosk: kiosk, host: format("main-opac-%02d", index + 1), state: index.even? ? :opac : :screensaver)
    end
    ["Children’s room", "Lobby", "Meeting room", "Local history", "Study area", "Youth services"].each_with_index do |name, index|
      destination = Kiosk.create!(name: name, slug: "overview-#{index}", kiosk_group: group, catalog_url: "https://catalog.example.com/")
      3.times { |host| KioskStatus.mark!(kiosk: destination, host: "branch-#{index}-opac-#{host + 1}", state: host.even? ? :opac : :screensaver) }
    end
    KioskSession.create!(kiosk_code: kiosk.slug, host: "main-opac-01", started_at: 1.hour.ago, ended_at: 10.minutes.ago)

    visit admin_root_path
    assert_selector '#overview-status-tab[aria-selected="true"]'
    assert_no_selector "h1", text: "Every screen"
    assert_no_link "Refresh overview"
    assert_no_link "+ Add slide"
    within "#overview-status-panel" do
      assert_selector ".admin-host-status", count: 36
      assert_no_text "Details"
      assert_no_text "Screensaver"
      assert_no_text "In use"
    end
    assert page.evaluate_script("document.querySelector('#overview-status-panel').getBoundingClientRect().bottom <= window.innerHeight"), "Status should fit without scrolling at desktop size"
    page.save_screenshot Rails.root.join("tmp/screenshots/admin-overview-status.png")

    find("#overview-status-tab").send_keys(:arrow_right)
    assert_selector '#overview-stats-tab[aria-selected="true"]'
    assert_selector "canvas"
    assert_selector "canvas[width]:not([width='0'])"
    page.save_screenshot Rails.root.join("tmp/screenshots/admin-overview-stats.png")
    select "Today", from: "Date range"
    assert_selector '#overview-stats-tab[aria-selected="true"]'
    assert_field "Start date", with: Date.current.to_s
    # The date fields change before Turbo replaces the report. Wait for the
    # hourly chart so the following tab action targets the completed response.
    assert_selector "canvas[aria-label='Usage sessions by hour'][width]:not([width='0'])"
    find("#overview-stats-tab").send_keys(:home)
    assert_selector '#overview-status-tab[aria-selected="true"]'

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.save_screenshot Rails.root.join("tmp/screenshots/admin-overview-mobile.png")
  end

  test "the JSON refresh updates rows and counters without replacing tabs or edited filters" do
    status = KioskStatus.mark!(kiosk: kiosks(:one), host: "first-opac", state: :screensaver)
    visit admin_root_path
    assert_selector ".admin-host-status.is-idle", text: "first-opac"
    assert_selector '.admin-host-status[aria-label*="Screensaver"]', text: "first-opac"
    click_link "Stats", exact: true
    fill_in "Start date", with: Date.current - 3
    page.execute_script("window.overviewBeforeRefresh = document.querySelector('.admin-overview')")

    KioskStatus.mark!(kiosk: kiosks(:one), host: "first-opac", state: :opac)
    added = KioskStatus.mark!(kiosk: kiosks(:one), host: "second-opac", state: :opac)
    kiosks(:one).update!(name: "Library <img src=x onerror=window.overviewInjected=true>")
    KioskSession.create!(kiosk_code: kiosks(:one).slug, host: "first-opac", started_at: 10.minutes.ago)
    page.execute_script("window.testOverviewRefresh()")

    assert_selector '[data-metric="in_use"]', text: "2", exact_text: true
    assert_selector '[data-metric="usage_sessions"]', text: "1", exact_text: true
    assert_selector '#overview-stats-tab[aria-selected="true"]'
    assert_field "Start date", with: (Date.current - 3).to_s
    assert page.evaluate_script("window.overviewBeforeRefresh === document.querySelector('.admin-overview')")
    assert_nil page.evaluate_script("window.overviewInjected")
    click_link "Live status", exact: true
    assert_selector ".admin-host-status.is-active", text: "first-opac"
    assert_selector '.admin-host-status[aria-label*="In use"]', text: "first-opac"
    assert_selector ".admin-host-status.is-active", text: "second-opac"
    assert_text "Library <img src=x onerror=window.overviewInjected=true>"
    assert_no_selector ".admin-status-card img"

    status.destroy!
    added.destroy!
    page.execute_script("window.testOverviewRefresh()")
    assert_text "Waiting for your kiosks"
    assert_no_selector ".admin-host-status"
    assert_selector '[data-metric="in_use"]', text: "0", exact_text: true
  end

  test "status card layout stays consistent after visiting stats and polling" do
    4.times do |index|
      kiosk = Kiosk.create!(name: "Layout kiosk #{index}", slug: "layout-#{index}", catalog_url: "https://catalog.example.com/")
      (index.zero? ? 9 : 3).times do |host|
        KioskStatus.mark!(kiosk: kiosk, host: "layout-#{index}-host-#{host}", state: :opac)
      end
      KioskSession.create!(kiosk_code: kiosk.slug, host: "layout-#{index}-host-0", started_at: 1.hour.ago, ended_at: 10.minutes.ago)
    end

    [1440, 1370, 1360, 1280].each do |width|
      page.driver.browser.manage.window.resize_to(width, 1000)
      visit admin_root_path
      before = status_layout
      click_link "Stats", exact: true
      click_link "Live status", exact: true
      assert_equal before, status_layout, "Tab switch changed layout at #{width}px"

      click_link "Stats", exact: true
      page.execute_script("window.testOverviewRefresh()")
      assert_selector '[data-overview-target="refreshStatus"]', text: /Updated/
      click_link "Live status", exact: true
      assert_equal before, status_layout, "Polling changed layout at #{width}px"

      visit admin_root_path(tab: "stats")
      click_link "Live status", exact: true
      assert_equal before, status_layout, "Loading with stats selected changed layout at #{width}px"
    end
  end

  test "failed refreshes retain the last status and recover on the next interval" do
    visit admin_root_path
    assert_text "Waiting for your kiosks"
    KioskStatus.mark!(kiosk: kiosks(:one), host: "retained-opac", state: :opac)
    page.execute_script("window.testOverviewRefresh()")
    assert_selector ".admin-host-status.is-active", text: "retained-opac"
    assert_no_text "Waiting for your kiosks"
    page.execute_script("window.originalOverviewFetch = window.fetch; window.fetch = () => Promise.reject(new Error('synthetic outage')); window.testOverviewRefresh()")
    assert_text "Live updates unavailable. Retrying…"
    assert_selector ".admin-host-status.is-active", text: "retained-opac"

    KioskStatus.mark!(kiosk: kiosks(:one), host: "retained-opac", state: :screensaver)
    page.execute_script("window.fetch = window.originalOverviewFetch; window.testOverviewRefresh()")
    assert_selector ".admin-host-status.is-idle", text: "retained-opac"
    assert_selector '[data-overview-target="refreshStatus"]', text: /Updated/
  end

  private

  def status_layout
    page.evaluate_script(<<~JS)
      (() => {
        const grid = document.querySelector('.admin-status-grid');
        const box = grid.getBoundingClientRect();
        return {
          viewport: document.documentElement.clientWidth,
          grid: [box.width, getComputedStyle(grid).gridTemplateColumns],
          cards: Array.from(grid.children, card => {
            const bounds = card.getBoundingClientRect();
            return [card.querySelector('h3').textContent.trim(), bounds.x - box.x, bounds.y - box.y, bounds.width, bounds.height];
          })
        };
      })()
    JS
  end
end
