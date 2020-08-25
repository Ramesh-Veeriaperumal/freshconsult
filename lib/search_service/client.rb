module SearchService
  class Client
    MULTI_QUERY_TIMEOUT = 10
    attr_accessor :account_id
    ACCOUNT_SIGNUP_SUPPORTED_LANG = ['ja-JP'].freeze

    def initialize(account_id)
      @account_id = account_id
    end

    def query(payload = nil, uuid = nil, additional_log_info = {})
      uuid ||= fetch_uuid
      query_request = SearchService::Request.new(query_path, :post, uuid, payload, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id, additional_log_info)
      query_request.response
    end

    def analytics_query(payload = nil, uuid = nil, additional_log_info = {})
      uuid ||= fetch_uuid
      query_request = SearchService::Request.new(analytics_query_path, :post, uuid, payload, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id, additional_log_info)
      query_request.response
    end

    def multi_query(payload = nil, uuid = nil, additional_log_info = {})
      uuid ||= fetch_uuid
      query_request = SearchService::Request.new(multi_query_path, :post, uuid, payload, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id, additional_log_info, MULTI_QUERY_TIMEOUT)
      query_request.response
    end

    def multi_aggregate(payload = nil, uuid = nil, additional_log_info = {})
      uuid ||= fetch_uuid
      query_request = SearchService::Request.new(multi_aggregate_path, :post, uuid, payload, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id, additional_log_info)
      query_request.response
    end

    def aggregate(payload = nil, uuid = nil, additional_log_info = {})
      uuid ||= fetch_uuid
      query_request = SearchService::Request.new(aggregate_path, :post, uuid, payload, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id, additional_log_info)
      query_request.response
    end

    def write_object(entity, version, parent_id, type, locale = nil)
      uuid = fetch_uuid
      payload = { payload: entity.to_esv2_json, version: version, parent_id: parent_id }
      payload.merge!({ language: locale }) if locale.present?
      write_request = SearchService::Request.new(write_path(type, entity.id), :post, uuid, payload.to_json, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id)
      write_request.response
    end

    # Time published from RMQ used as version stamp
    def write_count_object(entity, version)
      uuid = fetch_uuid
      type = 'ticketanalytics'
      payload = { payload: entity.to_search_count_es_json, version: version }
      path = write_path(type, entity.id)
      write_request = SearchService::Request.new(path, :post, uuid, payload.to_json, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), Account.current.id)
      Rails.logger.debug("Count search Service Request Write account_id :: #{Account.current.id} :: UUID :: #{uuid.inspect} :: path :: #{path} :: version :: #{version}")
      write_request.response
    end

    def delete_object(type, id)
      uuid = fetch_uuid
      delete_request = SearchService::Request.new(delete_path(type, id), :delete, uuid, {}.to_json, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id)
      delete_request.response
    end

    def delete_by_query(type, params)
      uuid = fetch_uuid
      delete_request = SearchService::Request.new(delete_by_query_path(type), :delete, uuid, { filters: params }.to_json, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id)
      delete_request.response
    end

    def tenant_bootstrap
      uuid = fetch_uuid
      body = { id: @account_id }
      body[:language] = Account.current.language if ACCOUNT_SIGNUP_SUPPORTED_LANG.include? Account.current.language
      tenant_request = SearchService::Request.new(tenants_path, :post, uuid, body.to_json, request_headers({ 'X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}" }.merge!(sandbox_header)), @account_id)
      tenant_request.response
    end

    def tenant_suspend
      uuid = fetch_uuid
      tenant_request = SearchService::Request.new("#{tenant_path}/suspend", :put, uuid, {}.to_json, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id)
      tenant_request.response
    end

    def tenant_destroy
      uuid = fetch_uuid
      tenant_request = SearchService::Request.new(tenant_path, :delete, uuid, {}.to_json, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id)
      tenant_request.response
    end

    def tenant_reactivate
      uuid = fetch_uuid
      tenant_request = SearchService::Request.new("#{tenant_path}/reactivate", :put, uuid, {}.to_json, request_headers('X-Request-Id' => uuid, 'X-Amzn-Trace-Id' => "Root=#{uuid}"), @account_id)
      tenant_request.response
    end

    private

      def fetch_uuid
        Thread.current[:message_uuid].try(:first) || UUIDTools::UUID.timestamp_create.hexdigest
      end

      def service_host
        ES_V2_CONFIG[:esv2_service_host]
      end

      def request_headers(headers={})
        {
          'Content-type' => 'application/json',
          'Content-Encoding' => 'gzip, deflate',
          'X-Auth-Token' => ES_V2_CONFIG[:auth_token],
          'User-Agent' => ''
        }.merge(headers)
      end

      # tenants URL for post requests
      def tenants_path
        path = SearchService::Constants::TENANTS_PATH % { product_name: ES_V2_CONFIG[:product_name] }
        "#{service_host}/#{path}"
      end

      # tenant URL for put/delete requests
      def tenant_path
        path = SearchService::Constants::TENANT_PATH % { product_name: ES_V2_CONFIG[:product_name], account_id: @account_id }
        "#{service_host}/#{path}"
      end

      def query_path
        path = SearchService::Constants::QUERY_PATH % { product_name: ES_V2_CONFIG[:product_name], account_id: @account_id }
        "#{service_host}/#{path}"
      end

      def multi_query_path
        path = SearchService::Constants::MULTI_QUERY_PATH % { product_name: ES_V2_CONFIG[:product_name], account_id: @account_id }
        "#{service_host}/#{path}"
      end

      def write_path(document_name, id)
        path = SearchService::Constants::WRITE_PATH % { product_name: ES_V2_CONFIG[:product_name], account_id: @account_id, document_name: document_name, id: id }
        "#{service_host}/#{path}"
      end

      def delete_path(document_name, id)
        path = SearchService::Constants::DELETE_PATH % { product_name: ES_V2_CONFIG[:product_name], account_id: @account_id, document_name: document_name, id: id }
        "#{service_host}/#{path}"
      end

      def delete_by_query_path(document_name)
        path = SearchService::Constants::DELETE_BY_QUERY_PATH % { product_name: ES_V2_CONFIG[:product_name], account_id: @account_id, document_name: document_name }
        "#{service_host}/#{path}"
      end

      def multi_aggregate_path
         path = SearchService::Constants::MULTI_AGGREGATE_PATH % { product_name: ES_V2_CONFIG[:product_name], account_id: @account_id }
        "#{service_host}/#{path}"
      end

      def aggregate_path
        path = SearchService::Constants::AGGREGATE_PATH % { product_name: ES_V2_CONFIG[:product_name], account_id: @account_id }
        "#{service_host}/#{path}"
      end

      def sandbox_header
        Account.current.sandbox? ? { 'X-Meta-Sandbox-Account' => true } : {}
      end
  end
end
