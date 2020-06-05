module Social
  class TwitterSurveyWorker < BaseWorker
    include Conversations::Twitter
    include Social::Twitter::Util
    include Social::Twitter::CentralUtil
    include KafkaCollector::CollectorRestClient

    sidekiq_options queue: :twitter_survey, retry: 0, failures: :exhausted

    def perform(args)
      args.symbolize_keys!
      post_central_command(args)
    end

    private

      def post_central_command(args)
        payload = default_command_schema('twitter', Social::Twitter::Constants::SURVEY_DM_COMMAND_NAME)
        payload[:data] = construct_payload_data(args)
        payload[:context] = construct_command_context(args[:tweet_type], args[:twitter_handle_id], args[:note_id], args[:stream_id])
        msg_id = generate_msg_id(payload)
        Rails.logger.info "Command from Helpkit to Twitter, Command: #{Social::Twitter::Constants::SURVEY_DM_COMMAND_NAME}, Msg_id: #{msg_id}"
        Channel::CommandWorker.perform_async({ payload: payload }, msg_id)
      rescue StandardError => e
        ::Rails.logger.error("Error while sending twitter survey command to central :: #{e.message}")
      end

      def construct_payload_data(args)
        {
           requester_screen_name: args[:requester_screen_name],
           user_id: args[:user_id],
           twitter_user_id: args[:twitter_user_id],
           survey_dm: args[:survey_dm]
        }
      end
  end
end
