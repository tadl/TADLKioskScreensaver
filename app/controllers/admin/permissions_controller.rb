# frozen_string_literal: true

class Admin::PermissionsController < Admin::ResourcesController
  private

  def resource_class = Permission
  def search_columns = %w[name description]
  def export_columns = %w[id name description created_at updated_at]
  def sort_columns = %w[name created_at updated_at]

  def record_attributes
    params.require(:permission).permit(:name, :description)
  end
end
