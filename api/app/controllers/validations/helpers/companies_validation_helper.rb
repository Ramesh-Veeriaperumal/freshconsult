class Helpers::CompaniesValidationHelper
  class << self
    def companies_custom_field_keys
      Account.current ? Account.current.company_form.custom_company_fields.collect(&:name) : []
    end
  end
end
