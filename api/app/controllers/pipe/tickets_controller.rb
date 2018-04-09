module Pipe
  class TicketsController < ::TicketsController
    private

      def sanitize_params
        super
        @pending_since = params[cname].delete(:pending_since) if params[cname].key?(:pending_since)
        @on_state_time = params[cname].delete(:on_state_time) if params[cname].key?(:on_state_time)
        @closed_at = params[cname].delete(:closed_at) if params[cname].key?(:closed_at)
      end

      def validate_params
        # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
        @ticket_fields = Account.current.ticket_fields_from_cache
        @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
        # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
        field = "ApiTicketConstants::PIPE_#{original_action_name.upcase}_FIELDS".constantize | ['custom_fields' => custom_fields]
        params[cname].permit(*field)
        set_default_values
        params_hash = params[cname].merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
        ticket = Pipe::TicketValidation.new(params_hash, @item, string_request_params?)
        render_custom_errors(ticket, true) unless ticket.valid?(original_action_name.to_sym)
      end

      def assign_protected
        super
        assign_ticket_states
      end

      def assign_on_state_time
        @item.ticket_states = Helpdesk::TicketState.new
        @item.ticket_states.on_state_time = @on_state_time
      end

      def assign_ticket_states
        assign_on_state_time if create?
        @item.ticket_states.pending_since = @pending_since if @item[:status] == PENDING
        @item.ticket_states.closed_at = @closed_at if @item[:status] == CLOSED
      end
  end
end
