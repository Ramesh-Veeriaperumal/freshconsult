module Admin::AutomationRules::Conditions
  class TicketValidation < ApiValidation
    include Admin::AutomationValidationHelper
    include Admin::AutomationConstants

    VALID_ATTRIBUTES = (DEFAULT_CONDITION_TICKET_FIELDS + OBSERVER_CONDITION_TICKET_FIELDS + 
                        DISPATCHER_CONDITION_TICKET_FIELDS + TICKET_STATE_FILTERS + TIME_BASED_FILTERS).uniq

    attr_accessor(*VALID_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position, :conditions

    validate :invalid_parameter_for_controller

    validate :shared_ownership_feature, if: -> { internal_agent_id.present? || internal_group_id.present? }
    validate :multi_product_feature, if: -> { product_id.present? }

    validate :ticket_conditions_attribute_type
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, _item, set, rule_type, _allow_string_param = false)
      @rule_type = rule_type
      @type_name = "conditions[:condition_set_#{set}][:ticket]"
      instance_variable_set("@conditions", request_params)
      super(initialize_params(request_params, VALID_ATTRIBUTES), nil, false)
    end

    def invalid_parameter_for_controller
      conditions.each do |field| 
        restricted_field = SUPERVISOR_INVLAID_CONDITION_FIELD
        restricted_field = restricted_field - [:subject] if Account.current.supervisor_with_text_field_enabled?
        unexpected_parameter(field.first.second) if supervisor_rule? && restricted_field.include?(field.first.second.to_sym)
        unexpected_parameter(field.first.second) if !supervisor_rule? && TIME_BASED_FILTERS.include?(field.first.second.to_sym)
      end
    end

    def ticket_conditions_attribute_type
      CONDITION_TICKET_FIELDS_HASH.each do |condition|
        attribute_value = safe_send(condition[:name])
        next if attribute_value.blank?
        @field_position = 1
        attribute_value.each do |each_attribute|
          condition_validation(condition, each_attribute)
          @field_position += 1
        end
      end
    end
  end
end
