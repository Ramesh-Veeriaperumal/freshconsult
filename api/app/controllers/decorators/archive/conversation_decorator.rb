module Archive
  class ConversationDecorator < ::ConversationDecorator
    def construct_json
      response_hash = {
        id: id,
        incoming: incoming,
        private: private,
        user_id: user_id,
        support_email: support_email,
        source: source,
        ticket_id: @ticket.display_id,
        created_at: created_at.try(:utc),
        updated_at: updated_at.try(:utc),
        attachments: attachments.map { |att| AttachmentDecorator.new(att).to_hash },
        cloud_files: cloud_files_hash
      }
      construct_note_body_hash.merge(response_hash)
    end

    def freshfone_call_proxy
      freshfone_call
    rescue StandardError => e
      Rails.logger.error("ArchiveConversation :: Freshfone :: Error :: #{e.message} :: #{e.backtrace}")
      {}
    end

    def freshcaller_call_proxy
      freshcaller_call
    rescue StandardError => e
      Rails.logger.error("ArchiveConversation :: Freshcaller :: Error :: #{e.message} :: #{e.backtrace}")
      {}
    end

    def to_hash
      [construct_json, freshfone_call_proxy, freshcaller_call_proxy, archive_old_data].inject(&:merge)
    end

    private

      def archive_old_data # Some methods are implemented only in Helpdesk::Note.
        if record.class.name == 'Helpdesk::Note'
          schema_less_properties = schema_less_note.try(:note_properties) || {}
          {
            cc_emails: cc_emails,
            to_emails: to_emails,
            bcc_emails: bcc_emails,
            from_email: from_email,
            category: schema_less_note.try(:category),
            email_failure_count: schema_less_note.failure_count,
            outgoing_failures: schema_less_properties[:errors]
          }
        else
          {
            cc_emails: record.cc_emails,
            to_emails: record.to_emails,
            bcc_emails: record.bcc_emails,
            from_email: record.from_email
          }
        end
      end
  end
end
