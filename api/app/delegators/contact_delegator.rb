class ContactDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options

  validates :company, presence: true, if: -> { company_id && self.changed.include?('customer_id')}
  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Account.current.contact_form.custom_drop_down_fields },
    drop_down_choices: proc { Account.current.contact_form.custom_dropdown_field_choices },
    required_attribute: :required_for_agent
  }
  }
end
