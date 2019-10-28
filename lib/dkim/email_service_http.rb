module Dkim
  class EmailServiceHttp
    include Dkim::Constants

    attr_accessor :account_id, :domain, :hrp

    def initialize(account_id, domain = nil)
      @account_id = account_id
      @domain = domain
      @hrp = HttpRequestProxy.new
    end

    def get_domains
      hrp.fetch_using_req_params(fetch_service_params(EMAIL_SERVICE_GET_DOMAINS, EMAIL_SERVICE_ACTION[:get_domains]), fetch_request_params(REQUEST_TYPES[:get]))
    end

    private

      def fetch_request_params(http_method)
        { method: http_method, auth_header: EMAIL_SERVICE_AUTHORISATION_KEY }
      end

      def fetch_service_params(email_service_url, email_service_action)
        case email_service_action
        when EMAIL_SERVICE_ACTION[:get_domains]  
          { domain: EMAIL_SERVICE_HOST, rest_url: email_service_url + "#{account_id.to_s}" }
        end
      end
  end
end
