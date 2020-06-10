module Social
  class FacebookSurveyWorker < BaseWorker
    include KafkaCollector::CollectorRestClient
    include ChannelIntegrations::Utils::Schema
    include Social::Util

    sidekiq_options queue: :facebook_survey, retry: 0, failures: :exhausted

    def perform(args)
      args.symbolize_keys!
      post_central_command(args)
    end

    private

      def post_central_command(args)
        payload = default_command_schema('facebook', Social::FB::Constants::SURVEY_DM_COMMAND_NAME)
        payload.merge!(account_full_domain: Account.current.host)
        payload[:data] = construct_payload_data(args)
        payload[:context] = construct_command_context(args)
        msg_id = generate_msg_id(payload)
        Rails.logger.info "Command from Helpkit to Facebook, Command: #{Social::FB::Constants::SURVEY_DM_COMMAND_NAME}, Msg_id: #{msg_id}"
        Channel::CommandWorker.perform_async({ payload: payload }, msg_id)
      rescue StandardError => e
        ::Rails.logger.error("Error while posting facebook_dm_survey command to central :: #{e.message}")
      end

      def construct_payload_data(args)
        {
          page_scope_id: args[:page_scope_id],
          survey_dm: args[:survey_dm],
          support_fb_page_id: args[:support_fb_page_id]
        }
      end

      def construct_command_context(args)
        {
          note_id: args[:note_id],
          user_id: args[:user_id]
        }
      end
  end
end
