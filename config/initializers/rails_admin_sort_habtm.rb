# config/initializers/rails_admin_sort_habtm.rb
RailsAdmin::Config::Fields::Types::HasAndBelongsToManyAssociation.class_eval do
  # sort both the “available” and “applied” lists by their labels
  def collection(scope = nil)
    super(scope).sort_by { |label, _value| label.to_s.downcase }
  end
end
