module Helpdesk
  module Services
    module Note
      include Redis::UndoSendRedis
      include ::Utils::Sanitizer

      UNDO_SEND_TIMER = 11.seconds
      NOTE_ASSOCIATED_ATTRIBUTES = [:support_email, :changes_for_observer,
                                    :disable_observer_rule, :nscname,
                                    :disable_observer, :send_survey,
                                    :include_surveymonkey_link,
                                    :quoted_text, :skip_notification,
                                    :last_note_id].freeze

      def save_note_later(publish_solution_later)
        ticket = notable
        build_note_and_sanitize
        ticket_requester = ticket.requester
        self.to_emails = if ticket_requester.second_email.present?
                           [ticket_requester.email, ticket_requester.second_email]
                         else
                           [ticket_requester.email]
                         end
        self.created_at = Time.now.utc
        attachment_list = []
        if attachments.present?
          attachment_list = attachments.map do |att|
            att.new_record? ? save_att_as_user_draft(att).id : att.id
          end
        end
        inline_attachment_list = inline_attachment_ids || []
        note_association_attributes = ::Helpdesk::Note::SCHEMA_LESS_ATTRIBUTES.map(&:to_sym) +
                                      NOTE_ASSOCIATED_ATTRIBUTES
        note_schema_less_associated_attributes = {}
        note_association_attributes.each do |data|
          note_schema_less_associated_attributes[data] = safe_send(data)
        end

        set_body_data(user_id, ticket.display_id, created_at.iso8601, note_body)
        args = { account_id: account_id,
                 user_id: user_id,
                 ticket_id: ticket.display_id,
                 note_basic_attributes: attributes,
                 note_schema_less_associated_attributes: note_schema_less_associated_attributes,
                 attachment_details: attachment_list,
                 inline_attachment_details: inline_attachment_list,
                 publish_solution_later: publish_solution_later }

        if valid?
          jobid = ::Tickets::UndoSendWorker.perform_in(UNDO_SEND_TIMER, args)
          undo_send_enqueued(user_id, ticket.display_id, created_at.iso8601, jobid)
          enqueue_undo_send_msg(ticket.display_id, user_id)
          true
        else
          false
        end
      end

      def save_note
        build_note_and_sanitize
        self.save
      end

      def save_note!
        build_note_and_sanitize
        self.save!
      end

      def update_note_attributes(attributes)
        attributes = sanitize_body_hash(attributes,:note_body_attributes,"body","full_text") if(attributes)
        self.update_attributes(attributes)
      end

      def build_note_and_sanitize
        build_note_body unless note_body
        if note_body
          self.load_full_text
          sanitize_body_and_unhtml_it(note_body,"body","full_text")
        end
      end

      # Used by API v2
      def assign_element_html(note_body_attributes, *elements)
        elements.each do |element|
          element_html = "#{element}_html".to_sym
          if note_body_attributes[element] && note_body_attributes[element_html].blank?
            formatted_text = body_html_with_formatting(CGI.escapeHTML(note_body_attributes[element]))
            note_body_attributes[element_html] = body_html_with_tags_renamed(formatted_text)
          end
        end
      end
    end
  end
end
