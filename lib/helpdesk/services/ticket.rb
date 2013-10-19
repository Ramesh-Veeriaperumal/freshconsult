module Helpdesk
  module Services
    module Ticket
      include Utils::Sanitizer

      def save_ticket
        sanitize_body_and_unhtml_it(ticket_body,"description") if ticket_body
        self.save
      end

      def save_ticket!
        sanitize_body_and_unhtml_it(ticket_body,"description") if ticket_body
        self.save!
      end

      def update_ticket_attributes(attributes)
        attributes = sanitize_body_hash(attributes,:ticket_body_attributes,"description") if(attributes)
        self.update_attributes(attributes)
      end
    end
  end
end
