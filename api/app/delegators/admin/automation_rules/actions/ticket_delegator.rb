module Admin::AutomationRules::Actions
  class TicketDelegator < BaseDelegator
    include Admin::AutomationDelegatorHelper
    include Admin::AutomationConstants

    validate :validate_action, if: -> { @actions.present? }

    def initialize(record, options = {})
      @actions = options[:actions]
      super(record)
    end

    def validate_action
      @actions.each do |action|
        next if DELEGATOR_IGNORE_FIELDS.include?(action[:field_name].to_sym)
        if DEFAULT_FIELDS_DELEGATORS.include?(action[:field_name].to_sym)
          if SEND_EMAIL_ACTION_FIELDS.include?(action[:field_name].to_sym)
            validate_send_email(action[:field_name], action[:email_to])
          elsif action[:field_name].to_sym ==:add_note
            validate_notify_agents(action[:field_name],action[:notify_agents]) if action[:notify_agents].present?
          else
            validate_default_ticket_field(action[:field_name], action[:value])
          end
        else
          custom_field = custom_ticket_fields.find { |t| t.name == "#{action[:field_name]}_#{current_account.id}" }
          field_not_found_error("action[#{action[:field_name]}]") if custom_field.blank?
          return if errors.messages.present?

          validate_custom_ticket_field(action, custom_field, custom_field.dom_type,
                                       :action) if custom_field.present?
        end
      end
    end
  end
end