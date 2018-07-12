class CompanyFieldChoice < ActiveRecord::Base

  self.primary_key = :id
  belongs_to_account

  stores_custom_field_choice  :custom_field_class => 'CompanyField',
                                :custom_field_id => :company_field_id

  validates_length_of :value, :in => 1..255

  before_update :update_segment_filter, if: :value_changed?
  after_destroy :update_segment_filter

  def update_segment_filter
    operation_type = frozen? ? 'deletion' : 'update'
    UpdateSegmentFilter.perform_async(custom_field: attributes, type: self.class.name, changes: changes, operation: operation_type)
  end
end
