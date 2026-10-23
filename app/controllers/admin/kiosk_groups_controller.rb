# frozen_string_literal: true

class Admin::KioskGroupsController < Admin::ResourcesController
  private

  def resource_class = KioskGroup
  def search_columns = %w[name slug location_shortname]
  def export_columns = %w[id name slug location_shortname created_at updated_at kiosks]
  def sort_columns = %w[name slug location_shortname created_at updated_at]
  def collection = super.includes(:kiosks)

  def prepare_form
    @kiosks = current_user.accessible_kiosks.order(:name)
  end

  def record_attributes
    attributes = params.require(:kiosk_group).permit(:name, :slug, :location_shortname, kiosk_ids: []).to_h
    require_association_ids!(current_user.accessible_kiosks, attributes["kiosk_ids"]) if attributes.key?("kiosk_ids")
    attributes
  end
end
