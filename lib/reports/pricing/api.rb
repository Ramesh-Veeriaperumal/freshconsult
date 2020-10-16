module Reports::Pricing
  module Api
    include HelpdeskReports::Constants::FreshvisualFeatureMapping

    API_RESOURCES = {
      create_tenant: 'applications/tenants',
      delete_tenant: 'applications/tenants/%{tenant_id}',
      update_restriction: 'applications/tenants/%{tenant_id}/restrictions',
      delete_restriction: 'applications/tenants/%{tenant_id}/restrictions'
    }.freeze

    SUCCESS_CODES = (200..204).freeze

    def create_tenant
      url = API_RESOURCES[:create_tenant]
      body = { tenantId: current_account.id }

      http_request('tenant', 'put', url, body)
    end

    # def delete_tenant
    #   url = format(API_RESOURCES[:delete_tenant], tenant_id: current_account.id)

    #   http_request('tenant', 'delete', url)
    # end

    # This is a upsert query.
    def update_restrictions
      url = format(API_RESOURCES[:update_restriction], tenant_id: current_account.id)
      body = construct_restrictions_payload
      Rails.logger.info "FD Payload for Account #{current_account.id}: #{body.inspect}"
      http_request('restriction', 'put', url, body)
    end

    # def delete_restrictions
    #   url = format(API_RESOURCES[:delete_restriction], tenant_id: current_account.id)

    #   http_request('restriction', 'delete', url)
    # end

    private

      def current_account
        @current_account ||= Account.current
      end

      def http_request(resource, action, url, body = nil)
        log_request_and_call(resource, action) do |connection|
          connection.safe_send(action) do |req|
            req.url url
            req.headers['auth'] = jwt_token
            req.headers['appName'] = FreshVisualsConfig['app_name']
            req.options.timeout = FreshVisualsConfig['timeout_for_pricing_api']
            if ['post', 'put'].include?(action)
              req.headers['Content-Type'] = 'application/json'
              req.body = body.to_json
            end
          end
        end
      end

      def log_request_and_call(resource, action)
        Rails.logger.debug "Reports pricing API called :: #{resource}_#{action}, for Account #{current_account.id}"
        response = yield(build_connection)

        Rails.logger.debug "Reports pricing API #{SUCCESS_CODES.include?(response.status) ? 'success' : 'error'} :: #{resource}_#{action}, response: #{response.body.inspect}, for Account #{current_account.id}"
        raise "Pricing API Invalid response, code: #{response.status}" unless SUCCESS_CODES.include?(response.status)
      rescue StandardError => e
        Rails.logger.error "Pricing API: Exception in log_request_and_call :: #{resource}_#{action}, error: #{e.message} for Account #{current_account.id}"
        NewRelic::Agent.notice_error(e, description: "Pricing API: Exception in log_request_and_call :: #{resource}_#{action} for Account #{current_account.id}")
      end

      def build_connection
        Faraday.new(FreshVisualsConfig['end_point']) do |faraday|
          faraday.response :json, content_type: /\bjson$/
          faraday.adapter Faraday.default_adapter
        end
      end

      def jwt_token
        JWT.encode freshreports_payload, FreshVisualsConfig['secret_key'], 'HS256', 'alg' => 'HS256', 'typ' => 'JWT'
      end

      def freshreports_payload
        {
          timezone: TimeZone.find_time_zone,
          sessionExpiration: Time.now.to_i + FreshVisualsConfig['session_expiration_for_pricing_api'],
          iat: Time.now.to_i,
          exp: Time.now.to_i + FreshVisualsConfig['session_expiration_for_pricing_api'],
          tenantId: current_account.id
        }
      end

      def construct_restrictions_payload
        payload = JSON.parse(CONFIG_PAYLOAD).deep_symbolize_keys
        payload[:curatedRestrictions] = []
        payload[:resourceRestrictions] = []

        payload = add_features_from_freshvisuals_mapping(payload)
        payload = add_resource_restriction_for_curated_reports(payload)
        payload = remove_duplicates(payload)
        payload = custom_modifications(payload)
        apply_restrictions(payload)
      end

      def add_features_from_freshvisuals_mapping(payload)
        FD_FRESVISUAL_FEATURE_MAPPING.keys.each do |feature|
          next unless Account.current.safe_send("#{feature}_enabled?")

          config = FD_FRESVISUAL_FEATURE_MAPPING[feature]
          config_payload = config.class == Array ? construct_payload_for_feature(config) : construct_payload_for_feature([config])

          config_payload[:featureConfig].keys.each do |report_type|
            payload[:featureConfig][:pages][report_type].merge!(config_payload[:featureConfig][report_type])
          end
          payload[:curatedRestrictions].push(*config_payload[:curatedRestrictions])
          payload[:resourceRestrictions].push(*config_payload[:resourceRestrictions])
        end

        payload
      end

      def construct_payload_for_feature(configs)
        payload = { featureConfig: {}, curatedRestrictions: [], resourceRestrictions: [] }

        configs.each do |config|
          config_type = config[:config_type]

          if config_type == CONFIG_TYPES[:FEATURE_CONFIGS]
            report_type = config[:report_type]
            feature = config[:value]

            payload[:featureConfig][report_type] ||= {}
            payload[:featureConfig][report_type][feature] = true
          elsif config_type == CONFIG_TYPES[:CURATED_REPORTS]
            payload[:curatedRestrictions] << config[:value]
          elsif config_type == CONFIG_TYPES[:RESOURCE_RESTRICTIONS]
            payload[:resourceRestrictions] << config[:value]
          end
        end

        payload
      end

      # Certain resources has to be enabled if some curated reports are enabled. This method handles that.
      def add_resource_restriction_for_curated_reports(payload)
        RESOURCE_CURATED_REPORTS_MAP.each do |resource, curated_reports|
          payload[:resourceRestrictions] << resource if payload[:curatedRestrictions].any? { |report| curated_reports.include?(report) }
        end
        payload
      end

      def remove_duplicates(payload)
        payload[:curatedRestrictions].uniq!
        payload[:resourceRestrictions].uniq!
        payload
      end

      def custom_modifications(payload)
        payload = custom_addition(payload)
        payload = custom_deletion(payload)
        payload
      end

      def custom_addition(payload)
        payload
      end

      def custom_deletion(payload)
        curated_reports_to_delete = []
        if Account.current.euc_hide_agent_metrics_enabled?
          # IN EUC admin should not see agent metrics.
          curated_reports_to_delete.push(CURATED_REPORTS[:agent_performance][:value])
        end

        payload[:curatedRestrictions].delete_if { |report| curated_reports_to_delete.include? report }
        payload
      end

      # The BM features we are maintaining are positive feature checks.
      # For example, if analytics_ticket_lifecycle_report is enabled customer can view analytics_ticket_lifecycle_report in Fresh reports.
      # curatedRestrictions and resourceRestrictions are negative, if we add analytics_ticket_lifecycle_report to curatedRestrictions customer cannot view that report.
      # So, we need to invert curatedRestrictions, resourceRestrictions we have built so far.
      def apply_restrictions(payload)
        payload[:curatedRestrictions] = CURATED_REPORTS_LIST - payload[:curatedRestrictions]
        payload[:resourceRestrictions] = RESOURCE_RESTRICTION_LIST  - payload[:resourceRestrictions]
        payload
      end
  end
end
