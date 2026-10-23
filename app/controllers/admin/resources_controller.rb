# frozen_string_literal: true

# Shared HTTP mechanics for the six admin resources. Each controller owns its
# query, editable attributes, association checks, and explicit export columns.
class Admin::ResourcesController < Admin::BaseController
  before_action :load_record, only: %i[show edit update destroy]
  helper_method :resource_class, :collection_path, :record_path, :edit_record_path,
    :new_record_path, :export_path, :bulk_path, :export_columns, :sort_columns, :filter_columns

  def index
    authorize! :read, resource_class
    @total = filtered_collection.count
    @page = [[params[:page].to_i, 1].max, [(@total / 24.0).ceil, 1].max].min
    @records = ordered_collection.offset((@page - 1) * 24).limit(24).to_a
  end

  def show
    authorize! :read, @record
  end

  def new
    @record = resource_class.new
    authorize! :create, @record
    prepare_form
    render "admin/resources/new"
  end

  def edit
    authorize! :update, @record
    prepare_form
    render "admin/resources/edit"
  end

  def create
    @record = resource_class.new
    authorize! :create, @record
    persist_record(:new)
  end

  def update
    authorize! :update, @record
    persist_record(:edit)
  end

  def destroy
    authorize! :destroy, @record
    @record.destroy!
    redirect_to collection_path, notice: "#{resource_class.model_name.human} deleted.", status: :see_other
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey
    redirect_to record_path(@record), alert: deletion_error, status: :see_other
  end

  def export
    authorize! :read, resource_class
    download(ordered_collection, params[:format])
  end

  def bulk
    operation = params[:operation].to_s
    return head :bad_request unless %w[csv json xml destroy].include?(operation)

    ids = Array(params[:ids]).reject(&:blank?).map(&:to_s).uniq
    if ids.empty? || ids.length > 500
      return redirect_to collection_path, alert: "Select between 1 and 500 records.", status: :see_other
    end

    action = operation == "destroy" ? :destroy : :read
    authorize! action, resource_class
    records = resource_class.accessible_by(current_ability, action).where(id: ids).order(:id)
    raise CanCan::AccessDenied unless records.size == ids.size

    if operation == "destroy"
      resource_class.transaction { records.each(&:destroy!) }
      redirect_to collection_path, notice: "#{ids.size} records deleted.", status: :see_other
    else
      download(records, operation)
    end
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey
    redirect_to collection_path, alert: "Nothing was deleted. #{deletion_error}", status: :see_other
  end

  private

  def load_record
    @record = resource_class.find(params[:id])
  end

  def persist_record(template)
    # HABTM setters can write immediately on existing records, before save!.
    resource_class.transaction do
      @record.assign_attributes(record_attributes)
      @record.save!
    end
    # A slide can be saved without a kiosk assignment, or an edit can remove the
    # actor's last assignment. Recompute access before choosing the destination.
    @current_ability = nil
    destination = current_ability.can?(:read, @record) ? record_path(@record) : collection_path
    redirect_to destination, notice: "#{resource_class.model_name.human} saved.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    prepare_form
    render "admin/resources/#{template}", status: :unprocessable_content
  end

  def prepare_form; end

  def collection
    resource_class.accessible_by(current_ability, :read)
  end

  def filtered_collection
    scope = collection
    query = params[:q].to_s.strip.first(200)
    if query.present?
      clauses = search_columns.map { |column| "#{resource_class.table_name}.#{column} ILIKE :query" }
      scope = scope.where(clauses.join(" OR "), query: "%#{resource_class.sanitize_sql_like(query)}%")
    end
    apply_attribute_filter(apply_filters(scope))
  end

  def apply_filters(scope) = scope
  def search_columns = %w[name]
  def sort_columns = %w[id created_at updated_at]
  def export_columns = %w[id created_at updated_at]
  def filter_columns = export_columns & resource_class.column_names

  def apply_attribute_filter(scope)
    field = params[:filter_field].to_s
    value = params[:filter_value].to_s.strip.first(500)
    return scope unless filter_columns.include?(field) && value.present?

    attribute = resource_class.arel_table[field]
    case params[:filter_operator]
    when "contains"
      return scope.none unless %i[string text].include?(resource_class.columns_hash.fetch(field).type)
      scope.where(attribute.matches("%#{resource_class.sanitize_sql_like(value)}%", nil, false))
    when "before", "after"
      cast_value = resource_class.type_for_attribute(field).cast(value)
      return scope.none if cast_value.nil?
      scope.where(params[:filter_operator] == "before" ? attribute.lt(cast_value) : attribute.gt(cast_value))
    else
      scope.where(attribute.eq(resource_class.type_for_attribute(field).cast(value)))
    end
  end

  def ordered_collection
    sort = sort_columns.include?(params[:sort]) ? params[:sort] : sort_columns.first
    direction = params[:direction] == "desc" ? :desc : :asc
    filtered_collection.reorder(sort => direction).order(:id)
  end

  def require_association_ids!(scope, ids)
    selected = Array(ids).reject(&:blank?).map(&:to_s).uniq
    raise CanCan::AccessDenied unless scope.where(id: selected).count == selected.size
    selected
  end

  def download(records, format)
    return head :bad_request unless %w[csv json xml].include?(format)

    requested = Array(params[:fields]).map(&:to_s)
    fields = requested.empty? ? export_columns : export_columns & requested
    return head :bad_request if fields.empty?

    exporter = Admin::Export.new(records, fields, ability: current_ability)
    send_data exporter.public_send(format), type: { "csv" => "text/csv", "json" => "application/json", "xml" => "application/xml" }.fetch(format),
      filename: "#{controller_name}-#{Date.current}.#{format}", disposition: "attachment"
  end

  def deletion_error
    "This record is still referenced, or its deletion is protected. Remove the related assignments first."
  end

  def collection_path = url_for(action: :index, only_path: true)
  def record_path(record) = url_for(action: :show, id: record.id, only_path: true)
  def edit_record_path(record) = url_for(action: :edit, id: record.id, only_path: true)
  def new_record_path = url_for(action: :new, only_path: true)
  def export_path = url_for(action: :export, only_path: true)
  def bulk_path = url_for(action: :bulk, only_path: true)
end
