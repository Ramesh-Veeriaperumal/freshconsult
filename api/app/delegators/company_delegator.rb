class CompanyDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options

  validates :custom_field, custom_field: {
    validatable_custom_fields: proc { Helpers::CompaniesValidationHelper.custom_drop_down_fields },
    drop_down_choices: proc { Helpers::CompaniesValidationHelper.custom_field_drop_down_choices }
  }, allow_nil: true
end
