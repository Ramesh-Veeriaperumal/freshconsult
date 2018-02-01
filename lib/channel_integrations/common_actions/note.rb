module ChannelIntegrations::CommonActions
  module Note
    include ChannelIntegrations::Utils::ActionParser
    include ChannelIntegrations::Constants

    def post_note(payload)
      data = payload[:data]
      note = construct_note data
      note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'] # replace the source from payload for Custom ticket sources.
      note.save_note
    end

    def post_reply(payload)
      data = payload[:data]
      note = construct_note data
      note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email']
      note.save_note
    end

    private

      def construct_note(data)
        note = Helpdesk::Note.new
        ticket = current_account.tickets.find_by_display_id(data[:ticket_id])
        raise 'Ticket not found' unless ticket
        note.notable_id = ticket.id
        note.user_id = data[:user_id]
        note.account_id = current_account.id
        note.notable_type = 'Helpdesk::Ticket'
        note.private = data[:private]
        note.incoming = false
        note.build_note_body(body: data[:body], body_html: data[:body])
        note
      end
  end
end
