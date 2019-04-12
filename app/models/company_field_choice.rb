class CompanyFieldChoice < ActiveRecord::Base

  self.primary_key = :id
  belongs_to_account

  stores_custom_field_choice  :custom_field_class => 'CompanyField',
                                :custom_field_id => :company_field_id

  validates_length_of :value, :in => 1..255

  before_save :construct_model_changes, on: :update

  before_update :update_segment_filter, if: :value_changed?
  before_destroy :save_deleted_company_field_choice_info
  after_destroy :update_segment_filter

  concerned_with :presenter

  publishable

  def update_segment_filter
    operation_type = frozen? ? 'deletion' : 'update'
    UpdateSegmentFilter.perform_async(custom_field: attributes, type: self.class.name, changes: changes, operation: operation_type)
  end

  def construct_model_changes
    @model_changes = self.changes.clone.to_hash
  end

  def save_deleted_company_field_choice_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end
end
