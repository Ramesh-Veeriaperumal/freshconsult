module CronWebhooks
  class AttachmentUserDraftCleanup < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_attachment_user_draft_cleanup, retry: 0, dead: true, failures: :exhausted

    def perform(args)
      perform_block(args) do
        attachment_user_draft_cleanup
      end
    end

    private

      def attachment_user_draft_cleanup
        Rails.logger.info '** Cleaning up stale UserDraft attachments **'
        cleanup_date = 2.days.ago.utc
        Helpdesk::MultiFileAttachment::AttachmentCleanup.new(cleanup_date: cleanup_date).cleanup
        Rails.logger.info '** Done **'
      end
  end
end
