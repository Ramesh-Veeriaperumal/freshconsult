module Admin::AutomationRules::Events
  class TicketValidation < ApiValidation
    include Admin::Automation::EventHelper
    include Admin::AutomationConstants

    DEFAULT_ATTRIBUTES = (Admin::AutomationConstants::DEFAULT_EVENT_TICKET_FIELDS +
                        Admin::AutomationConstants::SYSTEM_EVENT_FIELDS).uniq

    attr_accessor(*DEFAULT_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position, :custom_field_hash,
                  :validator_type

    validate :custom_survey_feature, if: -> { customer_feedback.present? }

    validate :event_attribute_type
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, custom_fields, rule_type)
      @type_name = :events
      @validator_type = :event
      super(initialize_params(request_params, DEFAULT_ATTRIBUTES, custom_fields, rule_type), nil, false)
    end

    def event_attribute_type
      attribute_type(EVENT_FIELDS_HASH + custom_field_hash)
    end
  end
end
