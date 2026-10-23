# frozen_string_literal: true

class Admin::HostsController < Admin::ResourcesController
  private

  def resource_class = Host
  def search_columns = %w[name location notes]
  def export_columns = %w[id name location active notes created_at updated_at]
  def sort_columns = %w[name location active created_at updated_at]

  def apply_filters(scope)
    %w[true false].include?(params[:active]) ? scope.where(active: params[:active] == "true") : scope
  end

  def record_attributes
    params.require(:host).permit(:name, :location, :active, :notes)
  end
end
