require "test_helper"

class AdminHelperTest < ActionView::TestCase
  test "uses the HTTPS photo URL provided by Google" do
    user = User.new(image_url: "https://lh3.googleusercontent.com/synthetic/photo")
    assert_equal user.image_url, admin_avatar_url(user)
  end

  test "missing, malformed and unsafe avatar URLs fall back to initials" do
    [nil, "", "invalid url", "http://example.com/avatar.png", "//example.com/avatar.png",
     "javascript:alert(1)", "data:image/png;base64,example", "https://user:password@example.com/avatar.png"].each do |url|
      assert_nil admin_avatar_url(User.new(image_url: url))
    end
  end
end
