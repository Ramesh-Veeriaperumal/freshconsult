module Freddy
  module Util
    include ::Freddy::Constants
    include Fdadmin::ApiCallConstants

    def perform(url, action)
      net_http_method = HTTP_METHOD_TO_CLASS_MAPPING[request_method.downcase.to_sym]
      content_type, body = construct_header(url)
      proxy_request = HTTParty::Request.new(net_http_method, url, options(content_type, body, action))
      rt_measure = Benchmark.measure do
        @proxy_response = proxy_request.perform
      end
      @parsed_response = @proxy_response.parsed_response
      FreddyLogger.log "url=#{url} account_id=#{params[:account_id]}, portal_id=#{params[:portal_id]}, response=#{@proxy_response.inspect}, time=#{rt_measure.real}"
    rescue StandardError => e
      @proxy_response = @proxy_response.try(:parsed_response)
      FreddyLogger.log "Error while processing #{url} serv request:: #{e.message} :: #{e.backtrace[0..10].inspect}"
      NewRelic::Agent.notice_error(e)
    end

    private

      def construct_header(url)
        if url.include? UPLOAD_FILE
          content_type = request.headers['CONTENT_TYPE']
          body = request.body.read
        else
          content_type = 'application/json'
          body = params.except(:version, :format, :controller, :action, :freddy).to_json
        end
        [content_type, body]
      end

      def options(content_type, body, action)
        secret = FreddySkillsConfig[action][:secret]
        current_account = Account.current
        portal_id = Portal.current.id.to_s || Account.current.main_portal.id.to_s
        query = { user_id: User.current.id, account_id: current_account.id.to_s, product: SERVICE, group_id: portal_id, domain: current_account.full_domain }
        {
          headers: safe_send("#{action}_headers", content_type, secret),
          query: query,
          body: body,
          timeout: FreddySkillsConfig[action][:timeout]
        }
      end

      def system42_headers(content_type, secret)
          jwt_token = construct_jwt_token(payload, secret)
          {
            'Authorization' => "Bearer #{jwt_token}",
            'Content-Type' => content_type,
            'X-Request-ID' => Thread.current[:message_uuid].to_s
          }
      end

      def flowserv_headers(content_type, secret)
          {
            'external-client-id' => Account.current.id.to_s,
            'fbots-service' => FreddySkillsConfig[:flowserv][:service],
            'product-id' => FreddySkillsConfig[:flowserv][:product_id],
            'Content-Type' => content_type
          }
      end

      def construct_jwt_token(payload, secret)
        JWT.encode payload, secret, 'HS256', { 'alg': 'HS256', 'typ': 'JWT' }
      end

      def payload(account_id = Account.current.id)
        {}.tap do |claims|
          claims[:aud] = account_id.to_s
          claims[:exp] = Time.zone.now.to_i + 10.minutes
          claims[:iat] = Time.zone.now.to_i
          claims[:iss] = SERVICE
        end
      end

      def request_method
        request.request_method
      end
  end
end
