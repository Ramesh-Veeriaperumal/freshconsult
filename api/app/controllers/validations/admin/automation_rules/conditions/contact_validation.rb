module Admin::AutomationRules::Conditions
  class ContactValidation < ApiValidation
    include Admin::AutomationValidationHelper

    VALID_ATTRIBUTES = Admin::AutomationConstants::CONDITION_CONTACT_FIELDS

    attr_accessor(*VALID_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position

    validate :contact_conditions_attribute_type
    validate :multi_language_enabled?, if: -> { language.present? }
    validate :multi_timezone_enabled?, if: -> { time_zone.present? }
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, _item, set, rule_type, _allow_string_param = false)
      @rule_type = rule_type
      @type_name = "conditions[:condition_set_#{set}][:contact]"
      super(initialize_params(request_params, VALID_ATTRIBUTES), nil, false)
    end

    def contact_conditions_attribute_type
      Admin::AutomationConstants::CONDITION_CONTACT_FIELDS_HASH.each do |condition|
        attribute_value = safe_send(condition[:name])
        next if attribute_value.blank?
        @field_position = 1
        attribute_value.each do |each_attribute|
          condition_validation(condition, each_attribute)
          @field_position += 1
        end
      end
    end

    def multi_language_enabled?
      Account.current.features?(:multi_language)
    end

    def multi_timezone_enabled?
      Account.current.multi_timezone_enabled?
    end
  end
end
