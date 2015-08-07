class CompanyDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options

  validates :custom_field, custom_field: {
    validatable_custom_fields: proc { Helpers::CompaniesValidationHelper.custom_company_fields_for_delegator },
    drop_down_choices: proc { Helpers::CompaniesValidationHelper.custom_company_dropdown_fields }
  }, allow_nil: true
end
