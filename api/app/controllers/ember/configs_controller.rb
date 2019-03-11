module Ember
  class ConfigsController < ApiApplicationController
    include HelperConcern
    skip_before_filter :load_object, only: [:show]
    before_filter :validate_query_params, :check_feature

    def show
      @config = fetch_config_data
    end

    private

      def fetch_freshvisuals_config
        payload = JWT.encode freshreports_payload, FreshVisualsConfig['secret_key'], 'HS256', { 'alg' => 'HS256', 'typ' => 'JWT' }
        FreshVisualsConfig['end_point'] + '?auth=' + payload + '&appName=' + FreshVisualsConfig['app_name']
      end

      def fetch_config_data
        {
          id: params[:id],
          config: safe_send("fetch_#{params[:id]}_config")
        }
      end

      def freshreports_payload
        {
          firstName: current_user.name,
          email: current_user.email,
          timezone: TimeZone.fetch_tzinfoname,
          tenantId: current_account.id,
          userId: current_user.id,
          sessionExpiration: Time.now.to_i + FreshVisualsConfig['session_expiration'].to_i,
          iat: Time.now.to_i,
          exp: Time.now.to_i + FreshVisualsConfig['session_expiration'].to_i
        }
      end

      def constants_class
        ConfigsConstants.to_s.freeze
      end

      def check_feature
        return if feature.present? && Account.current.safe_send("#{feature}_enabled?")

        render_request_error(:require_feature, 403, feature: feature.titleize)
      end

      def feature
        ConfigsConstants::CONFIG_FEATURES[params[:id].to_sym]
      end
  end
end
