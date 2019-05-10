module Admin::AutomationRules::Actions
  class TicketDelegator < BaseDelegator
    include Admin::AutomationDelegatorHelper
    include Admin::AutomationConstants

    attr_accessor :rule_type

    validate :validate_action, if: -> { @actions.present? }

    def initialize(record, options = {})
      self.rule_type = options[:rule_type]
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
            next if remove_event_performing_agent(action[:field_name].to_sym, action[:value])
            validate_default_ticket_field(action[:field_name], action[:value])
          end
        else
          custom_field = custom_ticket_fields.find { |t| t.name == "#{action[:field_name]}_#{current_account.id}" }
          validate_custom_ticket_field(action, custom_field, custom_field.dom_type,
                                       :action) if custom_field.present?
        end
      end
    end

    # -2 is for event performing agent, ticket creating agent
    def remove_event_performing_agent(field, value)
      if field == :internal_agent_id || field == :responder_id
        if !supervisor_rule? && value.to_s == "-2"
          return true
        end
      end
    end
  end
end