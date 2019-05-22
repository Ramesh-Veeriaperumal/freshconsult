module Admin::AutomationRules::Actions
  class TicketValidation < ApiValidation
    include Admin::Automation::ActionHelper
    include Admin::AutomationConstants

    DEFAULT_ATTRIBUTES = (Admin::AutomationConstants::DEFAULT_ACTION_TICKET_FIELDS +
                        Admin::AutomationConstants::SEND_EMAIL_ACTION_FIELDS +
                        Admin::AutomationConstants::INTEGRATION_ACTION_FIELDS).uniq

    attr_accessor(*DEFAULT_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position, :actions, :custom_field_hash,
                  :validator_type

    validates :actions, presence: true, data_type: { rules: Array, required: true },
                        array: { data_type: { rules: Hash }, hash: -> { ACTIONS_HASH } }

    validate :add_watcher_feature, if: -> { add_watcher.present? }
    validate :multi_product_feature, if: -> { product_id.present? }
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    validate :action_attribute_type

    def initialize(request_params, custom_fields, rule_type)
      @type_name = :actions
      @validator_type = :action
      instance_variable_set("@actions", request_params)
      super(initialize_params(request_params, DEFAULT_ATTRIBUTES, custom_fields, rule_type), nil, false)
    end

    def action_attribute_type
      attribute_type(ACTION_FIELDS_HASH + custom_field_hash)
    end
  end
end
