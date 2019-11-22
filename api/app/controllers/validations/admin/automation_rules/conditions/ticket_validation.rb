module Admin::AutomationRules::Conditions
  class TicketValidation < ApiValidation
    include Admin::ConditionHelper
    include Admin::AutomationConstants

    DEFAULT_ATTRIBUTES = (DEFAULT_CONDITION_TICKET_FIELDS + OBSERVER_CONDITION_TICKET_FIELDS +
        SUPERVISOR_CONDITION_TICKET_FIELDS + DISPATCHER_CONDITION_TICKET_FIELDS +
        TICKET_STATE_FILTERS + TIME_BASED_FILTERS + OBSERVER_CONDITION_FREDDY_FIELD).uniq

    attr_accessor(*DEFAULT_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position, :conditions, :custom_field_hash,
                  :validator_type, :custom_status_id

    validate :shared_ownership_feature, if: -> { internal_agent_id.present? || internal_group_id.present? }
    validate :multi_product_feature, if: -> { product_id.present? }
    validate :supervisor_text_field?, if: -> { contact_name.present? || company_name.present? || ((from_email.present? || to_email.present?) && supervisor_rule?) }
    validate :invalid_field_custom_status_id?
    validate :ticket_conditions_attribute_type

    validate :detect_thank_you_note_feature, if: -> { freddy_suggestion.present? }, on: :create
    validate :thank_you_note_condition_validation, if: -> { freddy_suggestion.present? }, on: :create
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, custom_fields, set, rule_type, additional_options = {})
      @events = additional_options[:events]
      @performer = additional_options[:performer]
      @type_name = :"conditions[:condition_set_#{set}][:ticket]"
      @validator_type = :condition
      instance_variable_set('@conditions', request_params)
      super(initialize_params(request_params, DEFAULT_ATTRIBUTES, custom_fields, rule_type), nil, false)
    end

    def ticket_conditions_attribute_type
      attribute_type(CONDITION_TICKET_FIELDS_HASH + custom_field_hash)
    end

    def invalid_field_custom_status_id?
      index = 0
      @conditions.each do |condition|
        index += 1
        errors[construct_key(:"[#{index}]")] << 'supervisor_custom_status_condition feature is not_enabled' if condition['field_name'] == TIME_AND_STATUS_BASED_FILTER[0] && !(Account.current.supervisor_custom_status_enabled?)
        errors[construct_key(:"[#{index}][custom_status_id]")] << :invalid_field if condition['custom_status_id'].present? && condition['field_name'] != TIME_AND_STATUS_BASED_FILTER[0]
      end
    end

    def thank_you_note_condition_validation
      event_validation = Admin::AutomationRules::Events::TicketValidation.new(@events, [], rule_type)
      performer_validation = Admin::AutomationRules::PerformerValidation.new(@performer, nil, false)
      unless (event_validation.reply_sent.present? || event_validation.note_type.present?) &&
             performer_validation.type == Va::Performer::CUSTOMER.to_i
        errors[construct_key(:freddy_suggestion)] << :expecting_note_or_reply_event
      end
    end
  end
end
