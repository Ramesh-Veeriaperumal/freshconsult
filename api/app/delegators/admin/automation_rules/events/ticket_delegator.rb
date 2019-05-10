module Admin::AutomationRules::Events
  class TicketDelegator < BaseDelegator
    include Admin::AutomationDelegatorHelper
    include Admin::AutomationConstants

    validate :validate_events, if: -> { @events.present? }
    FROM_TO = %i[from to]

    def initialize(record, options = {})
      @events = options[:events]
      super(record)
    end

    def validate_events
      @events.each do |event|
        next if DELEGATOR_IGNORE_FIELDS.include?(event[:field_name].to_sym)
        if DEFAULT_FIELDS_DELEGATORS.include?(event[:field_name].to_sym)
          FROM_TO.each do |type|
            validate_default_ticket_field(event[:field_name], event[type]) unless ANY_NONE.values.include? event[type]
          end
        else
          custom_field = custom_ticket_fields.find { |t| t.name == "#{event[:field_name]}_#{current_account.id}" }
          validate_custom_field_event(event, custom_field, :event) if custom_field.present?
        end
      end
    end

    private

    def validate_custom_field_event(event, custom_field, evaluate_on)
      case custom_field.dom_type.to_sym
      when :nested_field
        validate_nested_field(custom_field, event, evaluate_on)
      when :dropdown_blank
        FROM_TO.each do |type|
          validate_dropdown_field(event[:field_name], event[type],
              TicketsValidationHelper.custom_dropdown_field_choices["#{event[:field_name]}_#{current_account.id}"] +
                  ANY_NONE.values)
        end
      when :checkbox
        possible_values = CHECKBOX_VALUES
        not_included_error("events[#{event[:field_name]}]", possible_values) unless possible_values.include?(event[:value])
      else
        # custom_field present with invalid dom_type
        field_not_found_error(event[:field_name])
      end
    end
  end
end