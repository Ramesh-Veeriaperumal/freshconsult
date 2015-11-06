class ContactDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options

  validates :company, presence: true, if: -> { company_id && self.changed.include?('customer_id')}
  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Helpers::ContactsValidationHelper.custom_contact_fields_for_delegator },
    drop_down_choices: proc { Helpers::ContactsValidationHelper.custom_contact_dropdown_fields },
    required_attribute: :required_for_agent
  }
  }, if: -> { custom_field.is_a?(Hash) }
end
