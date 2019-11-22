module Admin::AutomationRules::Conditions
  class ContactValidation < ApiValidation
    include Admin::ConditionHelper
    include Admin::AutomationConstants

    DEFAULT_ATTRIBUTES = Admin::AutomationConstants::CONDITION_CONTACT_FIELDS

    attr_accessor(*DEFAULT_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position, :custom_field_hash,
                  :validator_type

    validate :contact_conditions_attribute_type
    validate :multi_language_enabled?, if: -> { language.present? }
    validate :multi_timezone_enabled?, if: -> { time_zone.present? }
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    def initialize(request_params, custom_fields, set, rule_type, additional_options = {})
      @type_name = :"conditions[:condition_set_#{set}][:contact]"
      @validator_type = :condition
      @events = additional_options[:events]
      @performer = additional_options[:performer]
      super(initialize_params(request_params, DEFAULT_ATTRIBUTES, custom_fields, rule_type), nil, false)
    end

    def contact_conditions_attribute_type
      attribute_type(Admin::AutomationConstants::CONDITION_CONTACT_FIELDS_HASH + custom_field_hash)
    end

    def multi_language_enabled?
      Account.current.features?(:multi_language)
    end

    def multi_timezone_enabled?
      Account.current.multi_timezone_enabled?
    end
  end
end
