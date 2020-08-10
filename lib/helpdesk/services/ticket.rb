module Helpdesk
  module Services
    module Ticket
      include ::Utils::Sanitizer
      include ::Redis::RedisKeys
      include ::Redis::DisplayIdRedis

      def save_ticket
        process_save_ticket do
          build_ticket_and_sanitize
          UnicodeSanitizer.encode_emoji(self.ticket_body, "description")
          self.save
        end
      end

      def save_ticket!
        process_save_ticket do
          build_ticket_and_sanitize
          UnicodeSanitizer.encode_emoji(self.ticket_body, "description")
          self.save!
        end
      end

      def process_save_ticket
        #Handles ticket creation failure due to duplicate display id.
        tries = 1
        begin
          yield
        rescue ActiveRecord::RecordNotUnique => e
          if e.message =~ /'index_helpdesk_tickets_on_account_id_and_display_id'/
            if (tries -= 1) >= 0
              reset_ticket_display_id(self.account.id)
              retry
            end
          elsif e.message =~ /'index_helpdesk_tickets_on_account_id_and_import_id'/
            raise e # Raising exception here so that it gets rescued in api_application_controller.rb
          else
            Rails.logger.error e.backtrace
            NewRelic::Agent.notice_error(e, {:description => "Error occured when saving ticket"})
          end
        end
      end

      def reset_ticket_display_id(account_id)
        self.display_id = nil
        display_id_key = TICKET_DISPLAY_ID % { :account_id => account_id }
        set_display_id_redis_key(display_id_key, TicketConstants::TICKET_START_DISPLAY_ID)
      end

      def update_ticket_attributes(attributes)
        attributes = sanitize_body_hash(attributes,:ticket_body_attributes,"description") if(attributes)
        attributes = UnicodeSanitizer.encode_emoji_hash(attributes, 'ticket_body_attributes', 'description') if attributes.present?
        self.update_attributes(attributes)
      end

      def assign_ticket_attributes(attributes)
        attributes = sanitize_body_hash(attributes,:ticket_body_attributes,"description") if(attributes)
        attributes = UnicodeSanitizer.encode_emoji_hash(attributes, 'ticket_body_attributes', 'description') if attributes.present?
        self.assign_attributes(attributes)
      end

      def build_ticket_and_sanitize
        build_ticket_body unless ticket_body
        sanitize_body_and_unhtml_it(ticket_body,"description") if ticket_body
      end
      
      # Used by API v2
      def assign_description_html(ticket_body_attributes)
        if ticket_body_attributes["description"] && ticket_body_attributes["description_html"].blank?
          formatted_text = body_html_with_formatting(CGI.escapeHTML(ticket_body_attributes["description"])) 
          ticket_body_attributes["description_html"] = body_html_with_tags_renamed(formatted_text)
        end
      end

    end
  end
end
