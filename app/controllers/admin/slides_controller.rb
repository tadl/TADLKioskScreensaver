# frozen_string_literal: true

class Admin::SlidesController < Admin::ResourcesController
  private

  def resource_class = Slide
  def search_columns = %w[title]
  def export_columns = %w[id title link display_seconds start_date end_date fallback created_at updated_at kiosks]
  def sort_columns = %w[title display_seconds start_date end_date fallback created_at updated_at]
  def collection = super.with_attached_image.includes(:kiosks)

  def apply_filters(scope)
    scope = scope.where(fallback: params[:fallback] == "true") if %w[true false].include?(params[:fallback])
    case params[:schedule]
    when "active" then scope.active_on(Date.current)
    when "upcoming" then scope.where("start_date > ?", Date.current)
    when "expired" then scope.where("end_date < ?", Date.current)
    else scope
    end
  end

  def prepare_form
    @kiosks = current_user.accessible_kiosks.order(:name)
  end

  def record_attributes
    fields = %i[title image display_seconds start_date end_date]
    fields << :fallback if current_user.admin?
    attributes = params.require(:slide).permit(*fields, kiosk_ids: []).to_h
    attributes.delete("image") if attributes["image"].blank?
    if attributes.key?("kiosk_ids")
      require_association_ids!(current_user.accessible_kiosks, attributes["kiosk_ids"])
    end
    attributes
  end
end
