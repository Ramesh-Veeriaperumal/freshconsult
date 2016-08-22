module Integrations
  class CtiDecorator < ApiDecorator
    delegate :id, :requester_id,  :responder_id, to: :record

    def ticket_id
      if record.recordable.is_a?(Helpdesk::Ticket)
        ticket_id = record.recordable.display_id
      elsif record.recordable.present?
        ticket_id = record.recordable.notable.display_id
      end
      ticket_id
    end

    def note_id
      if record.recordable.is_a?(Helpdesk::Note)
        ticket_id = record.recordable.id
      end
      ticket_id
    end
  end
end
