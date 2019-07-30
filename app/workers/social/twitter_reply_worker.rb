module Social
  class TwitterReplyWorker < BaseWorker
    include Conversations::Twitter
    include Social::Twitter::Util
    include Social::Twitter::CentralUtil

    sidekiq_options queue: :twitter_reply, retry: 0,  failures: :exhausted

    class TwitterReplyError < StandardError
    end

    def perform(args)
      args.symbolize_keys!
      ticket = Account.current.tickets.find(args[:ticket_id])
      note = ticket.notes.find(args[:note_id]) unless ticket.blank?
      return if note.blank?
      tweet_body = note.body.strip
      allow_attachments = true
      error_message, reply_twt, error_code = safe_send("send_tweet_as_#{args[:tweet_type]}", args[:twitter_handle_id], ticket, note, tweet_body, allow_attachments)
      post_success_or_failure_command(error_message, reply_twt, error_code, note.tweet.try(:stream_id), args)
      Rails.logger.info "Reply to twitter ticket sent successfully :: ticket id :: #{ticket.display_id} :: note id :: #{note.id} :: tweet id :: #{reply_twt}" unless error_message
      if error_message.present?
        Rails.logger.info "Reply to twitter ticket failed :: ticket id :: #{ticket.display_id}, note id :: #{note.id}"
        error_code ||= 0 # if no error code is returned, having zero as dummy error
        error_response = { code: error_code, message: error_message }
        update_errors_in_schema_less_notes(error_response, note.id)
        notify_iris(note.id)
        raise TwitterReplyError, "Error Code: #{error_code} :: ticket id :: #{ticket.display_id}, note id :: #{note.id} :: message #{error_message}"
      end
    end

    private

      def post_success_or_failure_command(error_message, reply_twt, error_code, stream_id, args)
        command_payload = construct_payload(error_message, reply_twt, error_code, stream_id, args)
        msg_id = generate_msg_id(command_payload)
        Rails.logger.info "Command from Twitter, Command: #{STATUS_UPDATE_COMMAND_NAME}, Msg_id: #{msg_id}"
        Channel::CommandWorker.perform_async({
                                               override_payload_type: ChannelIntegrations::Constants::PAYLOAD_TYPES[:command_to_helpkit],
                                               payload: command_payload
                                             }, msg_id)
      rescue StandardError => error
        ::Rails.logger.error("Error while posting twitter success/failure command to central :: #{error.message}")
      end

      def update_errors_in_schema_less_notes(error, note_id)
        schema_less_notes = Account.current.schema_less_notes.find_by_note_id(note_id)
        schema_less_notes.note_properties[:errors] ||= {}
        twitter_errors = { twitter: { error_code: error[:code], error_message: error[:message] } }
        schema_less_notes.note_properties[:errors].merge!(twitter_errors)
        schema_less_notes.save!
      end
  end
end
