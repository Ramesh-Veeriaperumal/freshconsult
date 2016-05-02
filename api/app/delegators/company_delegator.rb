class CompanyDelegator < BaseDelegator
  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Account.current.company_form.custom_drop_down_fields },
    drop_down_choices: proc { Account.current.company_form.custom_dropdown_field_choices },
    required_attribute: :required_for_agent
  }
  }

  def initialize(record, options)
    check_params_set(options[:custom_fields]) if options[:custom_fields].is_a?(Hash)
    super record
  end
end
