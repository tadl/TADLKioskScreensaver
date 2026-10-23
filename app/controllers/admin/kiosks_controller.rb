# frozen_string_literal: true

class Admin::KiosksController < Admin::ResourcesController
  private

  def resource_class = Kiosk
  def search_columns = %w[name slug location catalog_url]
  def export_columns = %w[id name slug catalog_url location kiosk_group_id created_at updated_at slides kiosk_group]
  def sort_columns = %w[name slug location slides_count created_at updated_at]
  def collection = super.includes(:kiosk_group, slides: { image_attachment: :blob })

  def apply_filters(scope)
    params[:kiosk_group_id].present? ? scope.where(kiosk_group_id: params[:kiosk_group_id]) : scope
  end

  def ordered_collection
    return super unless params[:sort] == "slides_count"

    count = Arel::Nodes::NamedFunction.new("COUNT", [Slide.arel_table[:id]])
    filtered_collection.left_joins(:slides).group("kiosks.id").select("kiosks.*")
      .order(params[:direction] == "desc" ? count.desc : count.asc).order(:id)
  end

  def assignable_slides
    scope = Slide.with_valid_dimensions
    current_user.admin? ? scope : scope.where(id: current_user.readable_slide_ids)
  end

  def prepare_form
    @slides = assignable_slides.order(:title)
    @groups = KioskGroup.where(id: current_user.accessible_kiosk_group_ids).order(:name)
  end

  def record_attributes
    fields = []
    fields += %i[name catalog_url location] if current_user.admin? || current_user.can?("manage_kiosks")
    fields << :slug if current_user.admin? || @record.new_record?
    fields << :kiosk_group_id if current_user.admin? || current_user.can?("manage_kiosks") || current_user.can?("manage_kioskgroups")
    attributes = params.require(:kiosk).permit(*fields, slide_ids: []).to_h
    if attributes["kiosk_group_id"].present?
      require_association_ids!(KioskGroup.where(id: current_user.accessible_kiosk_group_ids), [attributes["kiosk_group_id"]])
    end
    if attributes.key?("slide_ids")
      selected = require_association_ids!(assignable_slides, attributes["slide_ids"])
      hidden = @record.slide_ids - assignable_slides.ids
      attributes["slide_ids"] = selected + hidden
    end
    attributes
  end
end
