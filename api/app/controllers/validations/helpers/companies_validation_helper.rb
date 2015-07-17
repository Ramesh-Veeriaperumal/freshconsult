class Helpers::CompaniesValidationHelper
  class << self
    def companies_custom_field_keys
      Account.current ? Account.current.company_form.company_fields_from_cache.select { |field| field[:column_name] != 'default' }.collect(&:name) : []
    end
  end
end
