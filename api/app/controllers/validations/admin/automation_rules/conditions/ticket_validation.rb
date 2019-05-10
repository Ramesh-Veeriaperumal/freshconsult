module Admin::AutomationRules::Conditions
  class TicketValidation < ApiValidation
    include Admin::Automation::ConditionHelper
    include Admin::AutomationConstants

    DEFAULT_ATTRIBUTES = (DEFAULT_CONDITION_TICKET_FIELDS + OBSERVER_CONDITION_TICKET_FIELDS +
                        DISPATCHER_CONDITION_TICKET_FIELDS + TICKET_STATE_FILTERS + TIME_BASED_FILTERS).uniq

    attr_accessor(*DEFAULT_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position, :conditions, :custom_field_hash,
                  :validator_type

    validate :invalid_parameter_for_controller

    validate :shared_ownership_feature, if: -> { internal_agent_id.present? || internal_group_id.present? }
    validate :multi_product_feature, if: -> { product_id.present? }

    validate :ticket_conditions_attribute_type
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, custom_fields, set, rule_type)
      @type_name = :"conditions[:condition_set_#{set}][:ticket]"
      @validator_type = :condition
      instance_variable_set("@conditions", request_params)
      super(initialize_params(request_params, DEFAULT_ATTRIBUTES, custom_fields, rule_type), nil, false)
    end

    def invalid_parameter_for_controller
      # condition should be strictly like conditions = {'condition_set_1': { ticket: [{}], contact: [{}]}}, 'operator': 'or',
      # condition_set_2: .....

      return unless conditions.is_a?(Hash)
      conditions.each_pair do |_set_number, condition_set|
        next unless condition_set.is_a?(Hash)
        condition_set.each_pair do |_type, condition_fields|
          next unless condition_fields.is_a?(Array)
          all_field = condition_fields.map { |field| field[:field_name] }
          all_field.select!{ |field| field.present? && field.is_a?(String) }
          all_field = all_field.symbolize_keys
          restricted_field = SUPERVISOR_INVLAID_CONDITION_FIELD
          restricted_field = restricted_field - [:subject] if Account.current.supervisor_with_text_field_enabled?
          if supervisor_rule?
            (all_field & restricted_field).each do |invalid_field|
              unexpected_parameter(invalid_field) if invalid_field.present?
            end
          else
            (all_field & TIME_BASED_FILTERS).each do |invalid_field|
              unexpected_parameter(invalid_field) if invalid_field.present?
            end
          end
        end
      end
    end

    def ticket_conditions_attribute_type
      attribute_type(CONDITION_TICKET_FIELDS_HASH + custom_field_hash)
    end
  end
end
