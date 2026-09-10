require "application_system_test_case"

class RailsAdminAssetsTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    page.driver.browser.navigate.to("about:blank")
    page.execute_script <<~JS
      document.body.innerHTML = `
        <div id="admin-js" data-i18n-options="{}"></div>
        <div id="target" style="position:absolute;left:100px;top:100px;width:100px;height:50px"></div>
        <div id="positioned" style="position:absolute;width:10px;height:10px"></div>
        <label for="search">Search</label><input id="search">
        <ul id="sortable"><li id="first">First</li><li id="second">Second</li></ul>
      `;
    JS
    page.execute_script Rails.application.assets.find_asset("rails_admin/application.js").to_s
  end

  test "position treats untrusted strings as selectors instead of executing HTML" do
    executed = page.evaluate_async_script <<~JS
      const done = arguments[arguments.length - 1];
      window.positionPayloadExecuted = false;
      try {
        jQuery("#positioned").position({
          my: "left top",
          at: "right bottom",
          of: "<img src='invalid:' onerror='window.positionPayloadExecuted = true'>",
          collision: "none"
        });
      } catch (error) {
        // Invalid CSS selectors are expected to be rejected.
      }
      setTimeout(() => done(window.positionPayloadExecuted), 500);
    JS

    assert_equal false, executed
  end

  test "positioning and the RailsAdmin autocomplete and sortable widgets still work" do
    coordinates = page.evaluate_script <<~JS
      (() => {
        jQuery("#positioned").position({
          my: "left top", at: "right bottom", of: "#target", collision: "none"
        });
        const offset = jQuery("#positioned").offset();
        return [offset.left, offset.top];
      })()
    JS
    assert_equal [200, 150], coordinates

    page.execute_script <<~JS
      jQuery("#search").autocomplete({ source: ["First kiosk", "Second kiosk"], minLength: 0 });
      jQuery("#search").autocomplete("search", "First");
      jQuery("#sortable").sortable();
    JS
    assert_selector ".ui-autocomplete .ui-menu-item", text: "First kiosk"
    find(".ui-autocomplete .ui-menu-item", text: "First kiosk").click
    assert_field "Search", with: "First kiosk"
    assert_equal ["first", "second"], page.evaluate_script(
      'jQuery("#sortable").sortable("toArray")'
    )
  end
end
