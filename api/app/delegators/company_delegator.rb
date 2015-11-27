class CompanyDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options, :rename_fields_hash

  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Account.current.company_form.custom_drop_down_fields },
    drop_down_choices: proc { Account.current.company_form.custom_dropdown_field_choices },
    required_attribute: :required_for_agent
  }
  }
  def initialize(record)
    @rename_fields_hash = {}
    super record
  end
end
