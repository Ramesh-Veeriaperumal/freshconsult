module Channel
  class TicketsController < ::TicketsController
    CHANNEL_TICKETS_CONSTANTS_CLASS = 'ApiTicketConstants'.freeze
    CHANNEL_TICKETS_VALIDATION_CLASS = 'TicketValidation'.constantize

    include ChannelAuthentication
    
    before_filter :channel_client_authentication

    private

      def constants_class
        CHANNEL_TICKETS_CONSTANTS_CLASS
      end

      def validation_class
        CHANNEL_TICKETS_VALIDATION_CLASS
      end

      def validate_params
        # We are obtaining the mapping in order to swap the field names while rendering(both successful and erroneous requests), instead of formatting the fields again.
        @ticket_fields = Account.current.ticket_fields_from_cache
        @ticket_fields.each do |field|
          field.required = false
        end

        @name_mapping = TicketsValidationHelper.name_mapping(@ticket_fields) # -> {:text_1 => :text}
        # Should not allow any key value pair inside custom fields hash if no custom fields are available for accnt.
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
        field = "#{constants_class}::#{original_action_name.upcase}_FIELDS".constantize | ['custom_fields' => custom_fields]
        params[cname].permit(*field)
        set_default_values
        params_hash = params[cname].merge(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account), ticket_fields: @ticket_fields)
        ticket = validation_class.new(params_hash, @item, string_request_params?)
        render_custom_errors(ticket, true) unless ticket.valid?(original_action_name.to_sym)
      end
  end
end
