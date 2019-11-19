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
      hrp.fetch_using_req_params(
        fetch_service_params(EMAIL_SERVICE_GET_DOMAINS,
          EMAIL_SERVICE_ACTION[:get_domains]),
        fetch_request_params(REQUEST_TYPES[:get])
      )
    end

    def configure_domain
      hrp.fetch_using_req_params(
        fetch_service_params(EMAIL_SERVICE_CONFIGURE_DOMAIN,
          EMAIL_SERVICE_ACTION[:configure_domain]),
        fetch_request_params(REQUEST_TYPES[:post])
      )
    end
    
    def verify_domain
      hrp.fetch_using_req_params(
        fetch_service_params(EMAIL_SERVICE_VERIFY_DOMAIN,
          EMAIL_SERVICE_ACTION[:verify_domain]),
        fetch_request_params(REQUEST_TYPES[:post])
      )
    end

    private

      def fetch_request_params(http_method)
        { 
          method: http_method,
          auth_header: EMAIL_SERVICE_AUTHORISATION_KEY
        }
      end

      def fetch_service_params(email_service_url, email_service_action)
        service_params = { domain: EMAIL_SERVICE_HOST }
        case email_service_action
        when EMAIL_SERVICE_ACTION[:get_domains]  
          service_params.merge({ 
            rest_url: email_service_url + "#{account_id.to_s}"
          })
        when EMAIL_SERVICE_ACTION[:configure_domain] 
          service_params.merge({
            rest_url: email_service_url,
            body: build_configure_body.to_json 
          })
        when EMAIL_SERVICE_ACTION[:verify_domain] 
          service_params.merge({
            rest_url: email_service_url,
            body: build_verify_body.to_json 
          })
        end
      end

      def build_configure_body
        {
          "accountId": account_id,
          "signingDomain": domain
        }
      end
      
      def build_verify_body
        {
          "accountId": account_id,
          "domain": domain
        }
      end
  end
end
