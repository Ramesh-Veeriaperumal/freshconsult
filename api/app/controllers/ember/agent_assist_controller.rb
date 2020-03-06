module Ember
  class AgentAssistController < ApiApplicationController
    include ::AgentAssist::Util

    before_filter(only: [:onboard]) { |c| c.requires_launchparty_feature :freshid_org_v2 }
    before_filter(only: [:onboard]) { |c| c.requires_this_feature :freshconnect }
    ROOT_KEY = :agent_assist

    def onboard
      @result = onboard_agent_assist
    end

    def show
      if @agent_assist_config.present? && @agent_assist_config.key?(:domain)
        @agent_assist_config.delete(:email_sent)
        @agent_assist_config[:jwt_token] = set_jwt_token
      end
    end

    def request_demo
      return if @agent_assist_config.key?(:email_sent)

      RequestAgentAssistFeatureWorker.perform_async({})
      @agent_assist_config[:email_sent] = true
    end

    def bots
      agent_assist_bots
    end

    private

      def non_covered_feature
        render_request_error(:require_feature, 403, feature: :freshconnect)
      end

      def non_covered_launchparty_feature
        render_request_error(:require_feature, 403, feature: :freshid_org_v2)
      end

      def set_jwt_token
        @jwt_secret = construct_jwt_token(jwt_payload) if @agent_assist_config.present?
      end

      def load_object
        @agent_assist_config = scoper
      end

      def scoper
        current_account.account_additional_settings.agent_assist_config || {}
      end

      def set_root_key
        response.api_root_key = ROOT_KEY
      end
  end
end
