require "test_helper"

class Admin::RailsAdminControllerTest < ActionController::TestCase
  tests RailsAdmin::MainController

  setup do
    @routes = RailsAdmin::Engine.routes
    @request.session[:user_id] = users(:one).id
  end

  test "renders the dashboard for an administrator" do
    get :dashboard

    assert_response :success
    assert_select "body.rails_admin"
    assert_select "script[src*='rails_admin/application']"
  end

  test "renders the slide listing" do
    get :index, params: { model_name: "slide" }

    assert_response :success
    assert_select "table"
  end

  test "renders the slide upload and kiosk assignment form" do
    get :new, params: { model_name: "slide" }

    assert_response :success
    assert_select "input[type=file][name='slide[image]']"
    assert_select "select[name='slide[kiosk_ids][]']"
  end

  test "JSON export cannot invoke record methods from a crafted schema" do
    assert_no_difference "Slide.count" do
      get :export, params: {
        model_name: "slide",
        json: true,
        schema: { only: ["title"], methods: ["destroy"] }
      }
    end

    assert_response :success
    exported = JSON.parse(response.body)
    assert exported.any?
    assert exported.all? { |slide| slide.keys == ["title"] }
  end
end
