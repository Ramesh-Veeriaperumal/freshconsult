module Admin::AutomationRules::Conditions
  class TicketValidation < ApiValidation
    include Admin::Automation::ConditionHelper
    include Admin::AutomationConstants

    DEFAULT_ATTRIBUTES = (DEFAULT_CONDITION_TICKET_FIELDS + OBSERVER_CONDITION_TICKET_FIELDS +
        SUPERVISOR_CONDITION_TICKET_FIELDS + DISPATCHER_CONDITION_TICKET_FIELDS +
        TICKET_STATE_FILTERS + TIME_BASED_FILTERS).uniq

    attr_accessor(*DEFAULT_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position, :conditions, :custom_field_hash,
                  :validator_type

    validate :shared_ownership_feature, if: -> { internal_agent_id.present? || internal_group_id.present? }
    validate :multi_product_feature, if: -> { product_id.present? }
    validate :supervisor_text_field?, if: -> { contact_name.present? || company_name.present? || (from_email.present? && supervisor_rule?) }

    validate :ticket_conditions_attribute_type
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, custom_fields, set, rule_type)
      @type_name = :"conditions[:condition_set_#{set}][:ticket]"
      @validator_type = :condition
      instance_variable_set("@conditions", request_params)
      super(initialize_params(request_params, DEFAULT_ATTRIBUTES, custom_fields, rule_type), nil, false)
    end

    def ticket_conditions_attribute_type
      attribute_type(CONDITION_TICKET_FIELDS_HASH + custom_field_hash)
    end
  end
end
