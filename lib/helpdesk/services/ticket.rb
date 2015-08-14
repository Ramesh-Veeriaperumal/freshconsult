module Helpdesk
  module Services
    module Ticket
      include ::Utils::Sanitizer

      def save_ticket
        build_ticket_and_sanitize
        self.save
      end

      def save_ticket!
        build_ticket_and_sanitize
        self.save!
      end

      def update_ticket_attributes(attributes)
        attributes = sanitize_body_hash(attributes,:ticket_body_attributes,"description") if(attributes)
        self.update_attributes(attributes)
      end

      def build_ticket_and_sanitize
        build_ticket_body unless ticket_body
        sanitize_body_and_unhtml_it(ticket_body,"description") if ticket_body
      end
      
      def assign_description_html(ticket_body_attributes)
        if ticket_body_attributes["description"] && ticket_body_attributes["description_html"].blank?
          formatted_text = body_html_with_formatting(CGI.escapeHTML(ticket_body_attributes["description"])) 
          ticket_body_attributes["description_html"] = body_html_with_tags_renamed(formatted_text)
        end
      end

    end
  end
end
