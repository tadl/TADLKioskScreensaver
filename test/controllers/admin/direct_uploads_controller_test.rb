require "test_helper"

class Admin::DirectUploadsControllerTest < ActionDispatch::IntegrationTest
  test "anonymous requests with a valid CSRF token cannot create upload credentials" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get login_path
    token = Nokogiri::HTML(response.body).at_css('input[name="authenticity_token"]')["value"]
    assert_predicate token, :present?

    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: upload_parameters, as: :json,
        headers: { "X-CSRF-Token" => token }
    end
    assert_response :unauthorized
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "staff without slide permissions cannot create upload credentials" do
    sign_in(users(:two))

    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: upload_parameters, as: :json
    end
    assert_response :forbidden
  end

  test "administrators can create direct upload credentials" do
    sign_in(users(:one))

    assert_difference "ActiveStorage::Blob.count", 1 do
      post rails_direct_uploads_path, params: upload_parameters, as: :json
    end
    assert_response :success
    blob = ActiveStorage::Blob.find_signed!(response.parsed_body.fetch("signed_id"))
    assert_equal "synthetic-upload.png", blob.filename.to_s
    assert response.parsed_body.fetch("direct_upload").fetch("url").present?
  end

  test "scoped slide managers can create upload credentials" do
    user = users(:two)
    user.user_permissions.create!(permission: Permission.create!(name: "manage_slides")).kiosks << kiosks(:one)
    sign_in(user)

    assert_difference "ActiveStorage::Blob.count", 1 do
      post rails_direct_uploads_path, params: upload_parameters, as: :json
    end
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "public kiosk image downloads remain available without login" do
    slide = create_slide_with_image!(title: "Public kiosk image")

    get rails_blob_path(slide.image, only_path: true)
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "fake image bytes", response.body
  end

  private

  def upload_parameters
    { blob: { filename: "synthetic-upload.png", byte_size: 10,
      checksum: Base64.strict_encode64(Digest::MD5.digest("test bytes")), content_type: "image/png" } }
  end

  def sign_in(user)
    Rails.application.env_config["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: "test", uid: "synthetic-upload-user",
      info: { email: user.email, name: user.name }
    )
    stub_const(Object, :GOOGLE_DOMAIN, "example.com") { get "/auth/test/callback" }
    assert_redirected_to admin_root_path
  ensure
    Rails.application.env_config.delete("omniauth.auth")
  end
end
