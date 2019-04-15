module Admin::AutomationRules::Events
  class TicketValidation < ApiValidation
    include Admin::AutomationValidationHelper
    include Admin::AutomationConstants

    VALID_ATTRIBUTES = (Admin::AutomationConstants::DEFAULT_EVENT_TICKET_FIELDS +
                        Admin::AutomationConstants::SYSTEM_EVENT_FIELDS).uniq

    attr_accessor(*VALID_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position

    validate :custom_survey_feature, if: -> { customer_feedback.present? }

    validate :event_attribute_type
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, _item = nil, _allow_string_param = false)
      @type_name = :events
      super(initialize_params(request_params, VALID_ATTRIBUTES), nil, false)
    end

    def event_attribute_type
      EVENT_FIELDS_HASH.each do |event|
        attribute_value = safe_send(event[:name])
        next if attribute_value.blank?
        @field_position = 1
        attribute_value.each do |each_attribute|
          event_validation(event, each_attribute)
          @field_position += 1
        end
      end
    end
  end
end
