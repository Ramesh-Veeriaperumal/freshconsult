module Admin::AutomationRules::Conditions
  class ContactDelegator < BaseDelegator
    include Admin::AutomationDelegatorHelper
    include Admin::AutomationConstants

    validate :validate_contact, if: -> { @contact_conditions.present? }

    def initialize(record, options = {})
      # send only :contact hash in options
      @contact_conditions = options
      super(record)
    end

    def validate_contact
      @contact_conditions.each do |contact|
        if CONDITION_CONTACT_FIELDS.include?(contact[:field_name].to_sym)
          next if DELEGATOR_IGNORE_CONTACT_FIELDS.include?(contact[:field_name].to_sym)
          value = *contact[:value]
          validate_field_values(contact[:field_name], value, default_fields[contact[:field_name].to_sym] + [*ANY_NONE[:NONE]])
        else
          custom_field = contact_form_fields.find { |t| t.name == contact[:field_name] }
          validate_case_sensitive(contact, custom_field.dom_type, "contact[:#{contact[:field_name]}]") if contact.has_key? :case_sensitive
          validate_customer_field(contact, custom_field.dom_type.to_sym, 'contact') if custom_field.present?
        end
      end
    end
  end
end