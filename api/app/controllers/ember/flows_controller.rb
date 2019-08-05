module Ember
  class FlowsController < ApiApplicationController
    include ::Freddy::Util
    skip_before_filter :load_object

    def execute
      append_url = request.url.split('botflow/').last
      url = "#{FreddySkillsConfig[:flowserv][:host]}#{append_url}"
      result_string = request.url.split('/').last
      if ['productActions', 'productIntegrations'].include?(result_string)
        result_hash = { result_string => [] }
        @proxy_response = result_hash
        render status: :ok, json: @proxy_response.to_json
      else
        perform(url, :flowserv)
        render status: @proxy_response.code, json: @parsed_response.to_json
      end
    end

    private

      def feature_name
        FeatureConstants::BOTFLOW
      end
  end
end
