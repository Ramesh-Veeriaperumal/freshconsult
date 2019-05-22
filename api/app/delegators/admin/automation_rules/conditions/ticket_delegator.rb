module Admin::AutomationRules::Conditions
  class TicketDelegator < BaseDelegator
    include Admin::AutomationDelegatorHelper
    include Admin::AutomationConstants
    attr_accessor :rule_type
    validate :validate_conditions, if: -> { @ticket_conditions.present? }

    def initialize(record, options = {})
      @rule_type = record[:rule_type]
      #send only :ticket hash in options
      @ticket_conditions = options
      super(record)
    end

    def validate_conditions
      @ticket_conditions.each do |field|
        next if field.blank? || DELEGATOR_IGNORE_FIELDS.include?(field[:field_name].to_sym)
        if DEFAULT_FIELDS_DELEGATORS.include?(field[:field_name].to_sym)
          validate_default_ticket_field(field[:field_name], field[:value], field)
        else
          custom_field = custom_ticket_fields.find { |t| t.name == "#{field[:field_name]}_#{current_account.id}" }
          if custom_field.blank?
            field_not_found_error("condition[#{field[:field_name]}]")
            return
          end
          validate_case_sensitive(field, custom_field.dom_type, "condition[:#{field[:field_name]}]") if field.has_key? :case_sensitive
          validate_custom_ticket_field(field, custom_field, custom_field.dom_type,
                                       :condition) if custom_field.present?
        end
      end
    end
  end
end
