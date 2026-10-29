require "test_helper"

class KioskTest < ActiveSupport::TestCase
  test "catalog URLs require an HTTP or HTTPS host" do
    kiosk = kiosks(:one)

    ["https://", "https:///catalog", "https://catalog.example.com/bad path", "javascript:alert(1)"].each do |url|
      kiosk.catalog_url = url
      assert_not kiosk.valid?, "accepted invalid catalog URL #{url.inspect}"
      assert_not_empty kiosk.errors[:catalog_url]
    end
  end

  test "catalog URLs preserve HTTP and HTTPS paths queries and fragments" do
    kiosk = kiosks(:one)

    ["http://catalog.example.com:8080/search?q=books#results", "https://catalog.example.com/"].each do |url|
      kiosk.catalog_url = url
      assert_predicate kiosk, :valid?
      assert_equal url, kiosk.catalog_url
    end
  end
end
