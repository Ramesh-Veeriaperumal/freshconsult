module Admin::AutomationRules::Actions
  class TicketValidation < ApiValidation
    include Admin::AutomationValidationHelper
    include Admin::AutomationConstants

    VALID_ATTRIBUTES = (Admin::AutomationConstants::DEFAULT_ACTION_TICKET_FIELDS +
                        Admin::AutomationConstants::SEND_EMAIL_ACTION_FIELDS).uniq

    attr_accessor(*VALID_ATTRIBUTES)
    attr_accessor :invalid_attributes, :type_name, :rule_type, :field_position, :actions

    validates :actions, presence: true, data_type: { rules: Array, required: true },
              array: { data_type: { rules: Hash }, hash: -> { ACTIONS_HASH } }

    validate :invalid_parameter_for_controller
    validate :add_watcher_feature, if: -> { add_watcher.present? }
    validate :multi_product_feature, if: -> { product_id.present? }
    validate :errors_for_invalid_attributes, if: -> { invalid_attributes.present? }

    validate :action_attribute_type

    def initialize(request_params, _item, rule_type, _allow_string_param = false)
      @rule_type = rule_type
      @type_name = :actions
      instance_variable_set("@actions", request_params)
      super(initialize_params(request_params, VALID_ATTRIBUTES), nil, false)
    end

    def invalid_parameter_for_controller
      unexpected_parameter(:add_note) if (add_note.present? && supervisor_rule?)
      unexpected_parameter(:trigger_webhook) if (trigger_webhook.present? && supervisor_rule?)
      unexpected_parameter(:add_comment) if (add_comment.present? && !scenario_automation?)
      unexpected_parameter(:add_a_cc) if (add_a_cc.present? && !dispatcher_rule?)
      unexpected_parameter(:skip_notification) if (skip_notification.present? && !dispatcher_rule?)
    end

    def action_attribute_type
      ACTION_FIELDS_HASH.each do |action|
        attribute_value = safe_send(action[:name])
        next if attribute_value.blank?
        @field_position = 1
        attribute_value.each do |each_attribute|
          action_validation(action, each_attribute)
          @field_position += 1
        end
      end
    end
  end
end
