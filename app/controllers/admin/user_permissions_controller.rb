# frozen_string_literal: true

class Admin::UserPermissionsController < Admin::ResourcesController
  private

  def resource_class = UserPermission
  def sort_columns = %w[id user permission created_at updated_at]
  def collection = super.includes(:user, :permission, :kiosk_groups, :kiosks)
  def export_columns = %w[id user_id permission_id created_at updated_at user permission kiosks kiosk_groups]

  def ordered_collection
    return super unless %w[user permission].include?(params[:sort])

    association = params[:sort] == "user" ? :user : :permission
    attribute = association == :user ? User.arel_table[:email] : Permission.arel_table[:name]
    filtered_collection.joins(association)
      .reorder(params[:direction] == "desc" ? attribute.desc : attribute.asc).order("user_permissions.id")
  end

  def filtered_collection
    scope = collection
    query = params[:q].to_s.strip.first(200)
    if query.present?
      scope = scope.joins(:user).where("users.email ILIKE :query OR users.name ILIKE :query", query: "%#{User.sanitize_sql_like(query)}%")
    end
    scope = scope.where(permission_id: params[:permission_id]) if params[:permission_id].present?
    apply_attribute_filter(scope)
  end

  def prepare_form
    @permissions = current_user.admin? ? Permission.order(:name) : Permission.where.not(name: "admin").order(:name)
    @groups = KioskGroup.order(:name)
    @kiosks = Kiosk.order(:name)
  end

  def record_attributes
    attributes = params.require(:user_permission).permit(:permission_id, kiosk_ids: [], kiosk_group_ids: []).to_h
    allowed_permissions = current_user.admin? ? Permission.all : Permission.where.not(name: "admin")
    require_association_ids!(allowed_permissions, [attributes["permission_id"]]) if attributes.key?("permission_id")
    require_association_ids!(Kiosk.all, attributes["kiosk_ids"]) if attributes.key?("kiosk_ids")
    require_association_ids!(KioskGroup.all, attributes["kiosk_group_ids"]) if attributes.key?("kiosk_group_ids")
    attributes
  end
end
