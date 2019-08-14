module Ember
  class FlowsController < ApiApplicationController
    include ::Freddy::Util
    skip_before_filter :load_object

    def freshbot_proxy
      append_url = request.url.split(BOTFLOW_URL).last
      url = "#{FreddySkillsConfig[:flowserv][:host]}#{append_url}"
      perform(url, :flowserv)
      render status: @proxy_response.code, json: @proxy_response.to_json
    end

    def system42_proxy
      append_url = request.url.split(BOTFLOW_URL).last
      url = "#{FreddySkillsConfig[:system42][:host]}#{SYSTEM42_NAMESPACE}#{BOTFLOW_URL}#{append_url}"
      perform(url, :system42)
      render status: @proxy_response.code, json: @proxy_response.to_json
    end

    private

      def feature_name
        FeatureConstants::BOTFLOW
      end
  end
end
