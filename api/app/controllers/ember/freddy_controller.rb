module Ember
  class FreddyController < ApiApplicationController
    include ::Freddy::Util
    skip_before_filter :load_object

    def execute
      append_url = request.url.split('autofaq/').last
      url = "#{SYSTEM42_HOST}/api/v1/#{append_url}"
      perform(url, :system42)
      render status: @proxy_response.code, json: @parsed_response.to_json
    end

    private

      def feature_name
        FeatureConstants::AUTOFAQ
      end
  end
end
