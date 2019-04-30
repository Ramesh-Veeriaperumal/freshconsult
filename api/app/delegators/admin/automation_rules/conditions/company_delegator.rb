module Admin::AutomationRules::Conditions
  class CompanyDelegator < BaseDelegator
    include Admin::AutomationDelegatorHelper
    include Admin::AutomationConstants

    validate :validate_company, if: -> { @company_conditions.present? }

    def initialize(record, options = {})
      # send only :company hash in options
      @company_conditions = options
      super(record)
    end

    def validate_company
      @company_conditions.each do |company|
        if COMPANY_FIELDS.include?(company[:field_name].to_sym)
          company_field_validation(company)
        else
          custom_field = company_form_fields.find { |t| t.name == "cf_#{company[:field_name]}" }
          field_not_found_error("condition[:company][#{company[:field_name]}]") if custom_field.blank?
          return if errors.messages.present?

          validate_operator_custom_fields(company, custom_field.dom_type.to_sym, 'company') unless
              CUSTOM_FILEDS_WITH_CHOICES.include? custom_field.dom_type.to_sym
          validate_case_sensitive(company, custom_field.dom_type, "company[:#{company[:field_name]}]") if company.has_key? :case_sensitive
          validate_customer_field(company, custom_field.dom_type.to_sym, 'company') if custom_field.present?
        end
      end
    end

    def company_field_validation(company)
      case company[:field_name]
      when DOMAIN
        company_domain_validation(company[:value]) if company[:field_name] == DOMAIN
      when NAME
        company_name_validation(company[:value]) if company[:field_name] == NAME
      when RENEWAL_DATE
        validate_date_field(company[:value]) if company[:field_name] == RENEWAL_DATE
      else
        value = *company[:value]
        validate_field_values(company[:field_name], value, default_fields[company[:field_name].to_sym] + [*ANY_NONE[:NONE]])
      end
    end
  end
end