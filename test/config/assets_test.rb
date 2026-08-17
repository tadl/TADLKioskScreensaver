require "test_helper"

class AssetsTest < ActiveSupport::TestCase
  test "does not run generated Tailwind CSS through SassC" do
    assert_nil Rails.application.config.assets.css_compressor
  end
end
