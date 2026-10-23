require "test_helper"

class Admin::ExportTest < ActiveSupport::TestCase
  test "CSV cells cannot become spreadsheet formulas" do
    slide = slides(:one)
    slide.title = "=1+1"
    data = CSV.parse(Admin::Export.new([slide], ["title"]).csv, headers: true)
    assert_equal "'=1+1", data.first["title"]
  end
end
