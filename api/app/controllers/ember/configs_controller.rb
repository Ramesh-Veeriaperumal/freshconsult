module Ember
  class ConfigsController < ApiApplicationController
    include HelperConcern
    skip_before_filter :load_object, only: [:show]
    before_filter :validate_query_params, :check_feature
    LOAD_TYPE = 'home'.freeze

    def show
      @config = fetch_config_data
    end

    private

      def fetch_freshvisuals_config
        can_view_omni_analytics = User.current.privilege?(:view_analytics) && User.current.privilege?(:view_omni_analytics)
        return fetch_omnifreshvisuals_config if current_account.omni_bundle_account? && current_account.omni_reports_enabled? && can_view_omni_analytics
        payload = JWT.encode freshreports_payload, FreshVisualsConfig['secret_key'], 'HS256', { 'alg' => 'HS256', 'typ' => 'JWT' }
        FreshVisualsConfig['end_point'] + '?auth=' + payload + '&appName=' + FreshVisualsConfig['app_name']
      end

      def fetch_freshsales_config
        current_account.organisation.organisation_freshsales_account_url
      rescue StandardError => e
        Rails.logger.error "Exception in getting freshsales accounts from freshid. message:: #{e.message} backtrace:: #{e.backtrace.join("\n")}"
        render_base_error(:not_found, 404)
      end

      def fetch_omnifreshvisuals_config
        payload = JWT.encode freshvisuals_payload, OmniFreshVisualsConfig['secret_key'], 'HS256', { 'alg' => 'HS256', 'typ' => 'JWT' }
        OmniFreshVisualsConfig['end_point'] + '?buName=' + OmniFreshVisualsConfig['bu_name'] + '&auth=' + payload
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
          language: standard_lang_code(current_user.language || current_account.language),
          page: LOAD_TYPE,
          tenantId: current_account.id,
          portalUrl: "#{current_account.url_protocol}://#{current_account.full_domain}",
          userId: current_user.id,
          sessionExpiration: Time.now.to_i + FreshVisualsConfig['session_expiration'].to_i,
          iat: Time.now.to_i,
          exp: Time.now.to_i + FreshVisualsConfig['early_expiration'].to_i
        }
      end

      def freshvisuals_payload
        {
          uuid: Freshid::V2::Models::User.find_by_email(current_user.email).id,
          email: current_user.email,
          sessionExpiration: Time.now.to_i + OmniFreshVisualsConfig['session_expiration'].to_i,
          bundleId: current_account.omni_bundle_id,
          orgId: current_account.organisation.organisation_id,
          userId: current_user.id,
          iat: Time.now.to_i,
          exp: Time.now.to_i + OmniFreshVisualsConfig['early_expiration'].to_i
        }
      end

      def constants_class
        ConfigsConstants.to_s.freeze
      end

      def check_feature
        return if feature.blank? || Account.current.safe_send("#{feature}_enabled?")

        render_request_error(:require_feature, 403, feature: feature.titleize)
      end

      def feature
        ConfigsConstants::CONFIG_FEATURES[params[:id].to_sym]
      end

      def standard_lang_code(language)
        Languages::Constants::ANALYTICS_LANG_CODES[language.to_sym] || language
      end
  end
end
