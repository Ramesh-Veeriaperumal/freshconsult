class Helpers::CompaniesValidationHelper
  class << self
    def data_type_validatable_custom_fields
      Account.current.company_form.custom_company_fields.select { |c| c.field_type != :custom_dropdown }
    end

    def custom_field_drop_down_choices
      custom_drop_down_fields.map { |x| [x.name.to_sym, x.choices.map { |t| t[:value] }] }.to_h
    end

    def custom_drop_down_fields
      Account.current.company_form.custom_company_fields.select { |c| c.field_type == :custom_dropdown }
    end
  end
end
