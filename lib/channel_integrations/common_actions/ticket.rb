module ChannelIntegrations::CommonActions
  module Ticket
    include ChannelIntegrations::Utils::ActionParser
    include ChannelIntegrations::Constants

    def create_ticket(payload)
      ticket = construct_ticket(payload[:data])

      ticket.save_ticket!
      # TODO: return the response in the :show /api/v2/ticket/ format as it is in future.
      reply = default_success_format
      reply[:data] = { id: ticket.display_id, requester_id: ticket.requester_id }
      reply
    end

    private

      def construct_ticket(payload)
        description_html = payload.delete(:description)
        ticket = current_account.tickets.build(payload)
        ticket.ticket_body_attributes = { description_html: description_html } if description_html.present?
        ticket
      end
  end
end
