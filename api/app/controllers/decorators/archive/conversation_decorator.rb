module Archive
  class ConversationDecorator < ::ConversationDecorator
    def construct_json
      {
        body: body_html,
        body_text: body,
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
        cloud_files: cloud_files_hash,
      }.merge!(archive_old_data)
  end

    private

      def archive_old_data # Some methods are implemented only in Helpdesk::Note.
        if record.class.name == 'Helpdesk::Note'
          {
            cc_emails: cc_emails,
            to_emails: to_emails,
            bcc_emails: bcc_emails,
            from_email: from_email,
            category: schema_less_note.try(:category),
            email_failure_count: schema_less_note.failure_count
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
