module ChannelIntegrations::CommonActions
  module Note
    include ChannelIntegrations::Utils::ActionParser
    include ChannelIntegrations::Constants

    def create_note(payload)
      data = payload[:data]

      # we will try to use payload's source. defaults to note.
      data[:source] ||= Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
      note = construct_note(data)
      note.save_note!

      reply = default_success_format
      # TODO: Stick with api/v2/{ticket_id}/conversations show response format.
      reply[:data] = { id: note.id }
      reply
    end

    def create_reply(payload)
      data = payload[:data]

      # we will try to use payload's source. defaults to email.
      data[:source] ||= Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
      note = construct_note(data)
      note.save_note!

      reply = default_success_format
      # TODO: Stick with api/v2/{ticket_id}/conversations show response format.
      reply[:data] = { id: note.id }
      reply
    end

    private

      def construct_note(payload)
        ticket_id = payload.delete(:ticket_id)
        raise 'Ticket ID should be present' unless ticket_id
        ticket = load_ticket(ticket_id)
        archived_ticket = load_archived_ticket(ticket_id) unless ticket
        raise Social::Constants::TICKET_ARCHIVED if archived_ticket
        raise 'Ticket not found' unless ticket

        body_html = payload.delete(:body)

        note = ticket.notes.build(payload)
        note.note_body_attributes = { body_html: body_html } if body_html.present?

        note
      end

      def load_ticket(ticket_display_id)
        current_account.tickets.find_by_display_id(ticket_display_id)
      end

      def load_archived_ticket(ticket_display_id)
        current_account.archive_tickets.find_by_display_id(ticket_display_id)
      end
  end
end
