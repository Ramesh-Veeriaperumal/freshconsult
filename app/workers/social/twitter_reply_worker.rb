module Social
  class TwitterReplyWorker < BaseWorker
    include Conversations::Twitter
    include Social::Twitter::Util

    sidekiq_options queue: :twitter_reply, retry: 0, backtrace: true, failures: :exhausted

    def perform(args)
      args.symbolize_keys!
      ticket = Account.current.tickets.find(args[:ticket_id])
      note = ticket.notes.find(args[:note_id]) unless ticket.blank?
      return if note.blank?
      tweet_body = note.body.strip
      allow_attachments = true
      error_message, reply_twt, error_code = safe_send("send_tweet_as_#{args[:tweet_type]}", args[:twitter_handle_id], ticket, note, tweet_body, allow_attachments)
      Rails.logger.info 'Reply to twitter ticket sent successfully :: ticket id :: #{ticket.display_id} :: note id :: #{note.id} :: tweet id :: #{reply_twt}' unless error_message
      if error_message.present? 
        Rails.logger.info 'Reply to twitter ticket failed :: ticket id :: #{ticket.display_id}, note id :: #{note.id}'
        error_code ||= 0 # if no error code is returned, having zero as dummy error
        error_response = { code: error_code, message: error_message }
        update_errors_in_schema_less_notes(error_response, note.id)
        notify_iris(note.id)
      end
    end

    private

      def update_errors_in_schema_less_notes(error, note_id)
        schema_less_notes = Account.current.schema_less_notes.find_by_note_id(note_id)
        schema_less_notes.note_properties[:errors] ||= {}
        twitter_errors = { twitter: { error_code: error[:code], error_message: error[:message] } }
        schema_less_notes.note_properties[:errors].merge!(twitter_errors)
        schema_less_notes.save!      
      end
  end
end
