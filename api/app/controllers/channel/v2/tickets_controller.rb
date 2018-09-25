module Channel::V2
  class TicketsController < ::TicketsController

    CHANNEL_V2_TICKETS_CONSTANTS_CLASS = 'Channel::V2::TicketConstants'.freeze

    private

    def constants_class
      CHANNEL_V2_TICKETS_CONSTANTS_CLASS
    end

    def validation_class
      Channel::V2::TicketValidation
    end

    def sanitize_params
      super
      Channel::V2::TicketConstants::ASSOCIATE_ATTRIBUTES.each do |attribute|
        instance_variable_set("@#{attribute.to_s}",
                              params[cname].delete(attribute)) if params[cname].key?(attribute)
      end
    end

    def set_default_values
      super
      params[cname][:status] = ApiTicketConstants::OPEN if !@item.try("id") && !params[cname].key?(:status)
    end

    def assign_protected
      super
      set_attribute_accessors
      @item.display_id = @display_id if @display_id.present?
      @item.import_id = @import_id if @import_id.present?
      assign_ticket_states
    end

    def set_attribute_accessors
      if @import_id.present?
        @item.import_ticket = true
        if @item.due_by.present? || @item.frDueBy.present?
          @item.due_by = @item.frDueBy unless @item.due_by.present?
          @item.frDueBy = @item.due_by unless @item.frDueBy.present?
          @item.disable_sla_calculation = true
        else
          created_time = Time.parse(params[cname]['created_at']) rescue nil
          if @item.status == CLOSED
            due_by = @closed_at || ((created_time || Time.zone.now) + 1.month)
            @item.due_by = due_by
            @item.frDueBy = due_by
            @item.disable_sla_calculation = true
          elsif created_time.present?
            if created_time < (Time.zone.now - 1.month)
              due_by = (created_time || Time.zone.now) + 1.month
              @item.due_by = due_by
              @item.frDueBy = due_by
              @item.disable_sla_calculation = true
            else
              @item.sla_calculation_time = created_time
            end
          end
        end
      end
    end

    def assign_on_state_time
      @item.build_ticket_states
      @item.ticket_states.on_state_time = @on_state_time
    end

    def assign_ticket_states
      assign_on_state_time if create?
      Channel::V2::TicketConstants::ACCESSIBLE_ATTRIBUTES.each do |attribute|
        if instance_variable_get("@#{attribute}").present?
          @item.ticket_states.safe_send("#{attribute}=", instance_variable_get("@#{attribute}"))
        end
      end
    end
  end
end
