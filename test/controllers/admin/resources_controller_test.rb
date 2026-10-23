require "test_helper"

class Admin::SlidesControllerTest < ActionController::TestCase
  tests Admin::SlidesController

  setup { @request.session[:user_id] = users(:one).id }

  test "lists content and renders an upload form" do
    get :index
    assert_response :success
    assert_select "body.admin-app"
    assert_select "a", text: "+ Add slide"
    get :new
    assert_response :success
    assert_select "input[type=file][name='slide[image]']"
    assert_select "input[type=checkbox][name='slide[kiosk_ids][]']"
  end

  test "exports only allowed columns and cannot invoke record methods" do
    assert_no_difference "Slide.count" do
      get :export, params: { format: "json", fields: ["title", "destroy"], schema: { methods: ["destroy"] } }
    end
    assert_response :success
    assert response.parsed_body.all? { |row| row.keys == ["title"] }
    %w[csv xml].each do |format|
      get :export, params: { format: format, fields: ["title"] }
      assert_response :success
      assert_includes response.headers["Content-Disposition"], "attachment"
    end
  end

  test "search and schedule filters also apply to export" do
    slides(:one).update_columns(title: "Unique campaign", end_date: Date.current - 1)
    get :export, params: { format: "json", q: "Unique", schedule: "expired" }
    assert_equal ["Unique campaign"], response.parsed_body.map { |row| row["title"] }
  end

  test "field filtering uses typed comparisons and excludes unsupported columns" do
    get :export, params: { format: "json", filter_field: "title", filter_value: "Events" }
    assert_equal ["Events"], response.parsed_body.map { |row| row["title"] }
    get :export, params: { format: "json", filter_field: "title", filter_value: "' OR 1=1 --" }
    assert_empty response.parsed_body
    get :export, params: { format: "json", filter_field: "display_seconds", filter_operator: "after", filter_value: "12" }
    assert_equal ["Events"], response.parsed_body.map { |row| row["title"] }
    get :export, params: { format: "json", filter_field: "start_date", filter_operator: "before", filter_value: "invalid" }
    assert_empty response.parsed_body
  end

  test "nested exports do not reveal inaccessible kiosk assignments" do
    actor = users(:two)
    actor.user_permissions.create!(permission: Permission.create!(name: "manage_slides")).kiosks << kiosks(:one)
    shared = create_slide_with_image!(title: "Shared export")
    shared.kiosks = [kiosks(:one), kiosks(:two)]
    @request.session[:user_id] = actor.id
    get :export, params: { format: "json", fields: ["title", "kiosks"] }
    assert_equal [kiosks(:one).id], response.parsed_body.first.fetch("kiosks").map { |row| row["id"] }
  end

  test "scoped staff can save an unassigned slide without being redirected to a forbidden page" do
    actor = users(:two)
    actor.user_permissions.create!(permission: Permission.create!(name: "manage_slides")).kiosks << kiosks(:one)
    local = create_slide_with_image!(title: "Remove assignment")
    local.kiosks << kiosks(:one)
    @request.session[:user_id] = actor.id
    patch :update, params: { id: local.id, slide: { kiosk_ids: [""] } }
    assert_redirected_to admin_slides_path
    assert_empty local.reload.kiosk_ids
  end

  test "invalid replacement preserves the original image and rolls back assignments" do
    slide = create_slide_with_image!(title: "Original")
    slide.kiosks << kiosks(:one)
    original_blob_id = slide.image.blob.id
    Tempfile.create(["invalid-slide", ".png"]) do |file|
      MiniMagick.convert { |command| command.size "100x100"; command << "xc:red"; command << file.path }
      upload = Rack::Test::UploadedFile.new(file.path, "image/png")
      patch :update, params: { id: slide.id, slide: { image: upload, kiosk_ids: [kiosks(:two).id] } }
      assert_response :unprocessable_content
    end
    slide.reload
    assert_equal original_blob_id, slide.image.blob.id
    assert_equal [kiosks(:one).id], slide.kiosk_ids
  end

  test "scoped managers cannot edit shared slides or inject kiosk assignments" do
    actor = users(:two)
    permission = Permission.create!(name: "manage_slides")
    role = actor.user_permissions.create!(permission: permission)
    role.kiosks << kiosks(:one)
    local = create_slide_with_image!(title: "Local")
    local.kiosks << kiosks(:one)
    shared = create_slide_with_image!(title: "Shared")
    shared.kiosks = [kiosks(:one), kiosks(:two)]
    @request.session[:user_id] = actor.id
    patch :update, params: { id: shared.id, slide: { title: "Changed" } }
    assert_response :forbidden
    patch :update, params: { id: local.id, slide: { title: "Changed", kiosk_ids: [kiosks(:two).id] } }
    assert_response :forbidden
    assert_equal "Local", local.reload.title
    patch :update, params: { id: local.id, slide: { title: "Allowed", fallback: true } }
    assert_response :see_other
    assert_equal "Allowed", local.reload.title
    assert_not local.fallback?
  end

  test "bulk deletion checks every record before deleting anything" do
    actor = users(:two)
    role = actor.user_permissions.create!(permission: Permission.create!(name: "manage_slides"))
    role.kiosks << kiosks(:one)
    @request.session[:user_id] = actor.id
    assert_no_difference "Slide.count" do
      post :bulk, params: { ids: Slide.ids, operation: "destroy" }
    end
    assert_response :forbidden
  end

  test "selected record export cannot reveal inaccessible slides" do
    actor = users(:two)
    role = actor.user_permissions.create!(permission: Permission.create!(name: "manage_slides"))
    role.kiosks << kiosks(:one)
    @request.session[:user_id] = actor.id
    post :bulk, params: { ids: [slides(:one).id], operation: "json" }
    assert_response :forbidden
  end
end

class Admin::KiosksControllerTest < ActionController::TestCase
  tests Admin::KiosksController

  test "kiosks can be sorted by their assigned slide count" do
    @request.session[:user_id] = users(:one).id
    kiosks(:one).slides << create_slide_with_image!(title: "Counted")
    get :export, params: { format: "json", sort: "slides_count", direction: "desc", fields: ["id"] }
    assert_equal [kiosks(:one).id, kiosks(:two).id], response.parsed_body.map { |row| row["id"] }
  end

  test "a scoped slide manager can change content but not kiosk identity" do
    actor = users(:two)
    role = actor.user_permissions.create!(permission: Permission.create!(name: "manage_slides"))
    role.kiosks << kiosks(:one)
    slide = create_slide_with_image!(title: "Assigned")
    slide.kiosks << kiosks(:one)
    kiosk = kiosks(:one)
    @request.session[:user_id] = actor.id
    patch :update, params: { id: kiosk.id, kiosk: { name: "Injected", slug: "injected", catalog_url: "https://example.com", slide_ids: [slide.id] } }
    assert_response :see_other
    assert_equal "East Bay Branch", kiosk.reload.name
    assert_equal "east-bay", kiosk.slug
    assert_equal [slide.id], kiosk.slide_ids
    get :show, params: { id: kiosks(:two).id }
    assert_response :forbidden
  end

  test "invalid kiosk edits roll back changed slide assignments" do
    @request.session[:user_id] = users(:one).id
    kiosk = kiosks(:one)
    slide = create_slide_with_image!(title: "Assigned")
    kiosk.slides << slide
    patch :update, params: { id: kiosk.id, kiosk: { name: "", slide_ids: [""] } }
    assert_response :unprocessable_content
    assert_equal [slide.id], kiosk.reload.slide_ids
  end

  test "bulk deletion rolls back when any kiosk still has live statuses" do
    @request.session[:user_id] = users(:one).id
    KioskStatus.mark!(kiosk: kiosks(:two), host: "protected-host", state: :screensaver)
    assert_no_difference "Kiosk.count" do
      post :bulk, params: { ids: [kiosks(:one).id, kiosks(:two).id], operation: "destroy" }
    end
    assert_response :see_other
    assert_match "Nothing was deleted", flash[:alert]
  end
end

class Admin::KioskGroupsControllerTest < ActionController::TestCase
  tests Admin::KioskGroupsController

  test "group membership changes are transactional" do
    @request.session[:user_id] = users(:one).id
    group = KioskGroup.create!(name: "Original group", slug: "original")
    group.kiosks << kiosks(:one)
    patch :update, params: { id: group.id, kiosk_group: { name: "", kiosk_ids: [kiosks(:two).id] } }
    assert_response :unprocessable_content
    assert_equal [kiosks(:one).id], group.reload.kiosk_ids
    patch :update, params: { id: group.id, kiosk_group: { name: "Updated group", kiosk_ids: [kiosks(:two).id] } }
    assert_response :see_other
    assert_equal [kiosks(:two).id], group.reload.kiosk_ids
  end
end

class Admin::HostsControllerTest < ActionController::TestCase
  tests Admin::HostsController

  test "administrators can maintain and delete hosts while preserving history" do
    @request.session[:user_id] = users(:one).id
    post :create, params: { host: { name: "test-host.example.com", location: "Test library", active: true } }
    assert_response :see_other
    host = Host.find_by!(name: "test-host.example.com")
    usage = KioskSession.create!(host: host.name, kiosk_code: kiosks(:one).slug, started_at: 1.hour.ago, ended_at: 30.minutes.ago)
    delete :destroy, params: { id: host.id }
    assert_response :see_other
    assert_predicate usage.reload, :persisted?
  end

  test "ordinary staff cannot access host inventory" do
    @request.session[:user_id] = users(:two).id
    get :index
    assert_response :forbidden
  end
end

class Admin::PermissionsControllerTest < ActionController::TestCase
  tests Admin::PermissionsController

  test "administrators can maintain definitions and user managers only read them" do
    @request.session[:user_id] = users(:one).id
    post :create, params: { permission: { name: "synthetic_permission", description: "Test definition" } }
    assert_response :see_other
    definition = Permission.find_by!(name: "synthetic_permission")
    @request.session[:user_id] = users(:two).id
    users(:two).user_permissions.create!(permission: Permission.create!(name: "manage_users"))
    get :show, params: { id: definition.id }
    assert_response :success
    patch :update, params: { id: definition.id, permission: { name: "changed" } }
    assert_response :forbidden
  end
end

class Admin::LegacyRoutesTest < ActionDispatch::IntegrationTest
  test "legacy bookmarks require authentication and role creation is unavailable" do
    %w[/admin/slide /admin/slides /admin/hosts].each do |path|
      get path
      assert_redirected_to login_path
    end
    get "/admin/user_permissions/new"
    assert_response :not_found
  end
end

class Admin::UserPermissionsControllerTest < ActionController::TestCase
  tests Admin::UserPermissionsController

  setup do
    @manager = users(:two)
    @manager.user_permissions.create!(permission: Permission.create!(name: "manage_users"))
    @target = User.create!(name: "Test Staff", email: "target@example.com")
    @target_role = @target.user_permissions.find_by!(permission: permissions(:two))
    @request.session[:user_id] = @manager.id
  end

  test "user managers have visible access to their authorized workflows" do
    get :index
    assert_response :success
    assert_select "a", text: "Users & access"
    get :edit, params: { id: @target_role.id }
    assert_response :success
  end

  test "user managers cannot inject an admin permission or another identity" do
    patch :update, params: { id: @target_role.id, user_permission: { permission_id: permissions(:admin).id, user_id: @manager.id } }
    assert_response :forbidden
    assert_equal @target.id, @target_role.reload.user_id
    assert_not @target.reload.admin?
  end

  test "user managers cannot change their own role or an administrator role" do
    [@manager.user_permissions.first, user_permissions(:one)].each do |role|
      patch :update, params: { id: role.id, user_permission: { permission_id: permissions(:two).id } }
      assert_response :forbidden
    end
  end

  test "user managers can change eligible assignments" do
    patch :update, params: { id: @target_role.id, user_permission: { kiosk_ids: [kiosks(:one).id] } }
    assert_response :see_other
    assert_equal [kiosks(:one).id], @target_role.reload.kiosk_ids
  end
end

class Admin::DashboardControllerTest < ActionController::TestCase
  tests Admin::DashboardController

  test "anonymous visitors must log in" do
    get :index
    assert_redirected_to login_path
  end

  test "dashboard scopes status and usage to the staff account" do
    actor = users(:two)
    actor.user_permissions.first.kiosks << kiosks(:one)
    KioskStatus.mark!(kiosk: kiosks(:one), host: "visible-host", state: :screensaver)
    KioskStatus.mark!(kiosk: kiosks(:two), host: "hidden-host", state: :screensaver)
    KioskSession.create!(kiosk_code: kiosks(:two).slug, host: "hidden-host", started_at: 1.hour.ago, ended_at: 30.minutes.ago)
    @request.session[:user_id] = actor.id
    get :index
    assert_response :success
    assert_includes response.body, "visible-host"
    assert_not_includes response.body, "hidden-host"
  end
end
