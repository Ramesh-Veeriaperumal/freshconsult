class Helpers::CompaniesValidationHelper
  class << self
  def custom_company_fields
    Account.current.company_form.custom_company_fields.select { |c| c.field_type != :custom_dropdown }
  end

  def custom_company_dropdown_fields
    Account.current.company_form.custom_company_fields.select { |c| c.field_type == :custom_dropdown }.collect { |x| [x.name.to_sym, x.choices.collect { |t| t[:value] }] }.to_h
  end

  def custom_company_fields_for_delegator
    Account.current.company_form.custom_company_fields.select { |c| c.field_type == :custom_dropdown }
  end
  end
end
