module Helpdesk
  module Services
    module Note
      include Redis::UndoSendRedis
      include ::Utils::Sanitizer

      NOTE_ASSOCIATED_ATTRIBUTES = [:support_email, :changes_for_observer,
                                    :disable_observer_rule, :nscname,
                                    :disable_observer, :send_survey,
                                    :include_surveymonkey_link,
                                    :quoted_text, :skip_notification,
                                    :last_note_id].freeze

      def save_note_later(publish_solution_later, post_to_forum_topic)
        ticket = notable
        build_note_and_sanitize
        self.to_emails = [ticket.from_email]
        attachment_list = build_attachments || []
        inline_attachment_list = inline_attachment_ids || []
        note_schema_less_associated_attributes = build_note_schema_less_associated_attributes
        self.created_at = Time.now.utc
        set_body_data(user_id, ticket.display_id, created_at.iso8601, note_body)

        args = build_args_for_sidekiq(ticket.display_id,
                                      note_schema_less_associated_attributes,
                                      attachment_list,
                                      inline_attachment_list,
                                      publish_solution_later,
                                      post_to_forum_topic)

        send_to_sidekiq_and_set_redis_flags(args)
      end

      def save_note
        build_note_and_sanitize
        UnicodeSanitizer.encode_emoji(self.note_body, 'body', 'full_text')
        self.save
      end

      def save_note!
        build_note_and_sanitize
        UnicodeSanitizer.encode_emoji(self.note_body, 'body', 'full_text')
        self.save!
      end

      def update_note_attributes(attributes)
        attributes = sanitize_body_hash(attributes, :note_body_attributes, 'body', 'full_text') if attributes
        self.update_attributes(attributes)
      end

      def build_note_and_sanitize
        build_note_body unless note_body
        if note_body
          load_full_text
          sanitize_body_and_unhtml_it(note_body, 'body', 'full_text')
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

      def build_attachments
        if attachments.present?
          attachments.map do |att|
            att.new_record? ? save_att_as_user_draft(att).id : att.id
          end
        end
      end

      def build_note_schema_less_associated_attributes
        note_association_attributes = ::Helpdesk::Note::SCHEMA_LESS_ATTRIBUTES.map(&:to_sym) +
                                      NOTE_ASSOCIATED_ATTRIBUTES
        note_schema_less_associated_attributes = {}
        note_association_attributes.each do |data|
          note_schema_less_associated_attributes[data] = safe_send(data)
        end
        note_schema_less_associated_attributes
      end

      def build_args_for_sidekiq(ticket_display_id, note_schema_less_associated_attributes,
                                 attachment_list, inline_attachment_list, publish_solution_later, post_to_forum_topic)
        {
          account_id: account_id,
          user_id: user_id,
          ticket_id: ticket_display_id,
          note_basic_attributes: attributes,
          note_schema_less_associated_attributes: note_schema_less_associated_attributes,
          attachment_details: attachment_list,
          inline_attachment_details: inline_attachment_list,
          publish_solution_later: publish_solution_later,
          post_to_forum_topic: post_to_forum_topic
        }
      end

      def send_to_sidekiq_and_set_redis_flags(args)
        if valid?
          ticket_display_id = args[:ticket_id]
          jobid = ::Tickets::UndoSendWorker.perform_in(undo_send_timer_value, args)
          undo_send_enqueued(user_id, ticket_display_id, created_at.iso8601, jobid)
          enqueue_undo_send_traffic_cop_msg(ticket_display_id, user_id)
          true
        else
          false
        end
      end
    end
  end
end
