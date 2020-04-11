module Proactive
  class ProactiveServiceCall
    include ::Proactive::ProactiveJwtAuth

    def make_proactive_service_call
      HttpRequestWorker.perform_async(build_http_worker_args)
    end

    def build_generic_proactive_service_args
      {
        'domain': ProactiveServiceConfig['service_url'],
        'auth_header': build_proactive_header,
        'skip_blacklist_verification': true
      }
    end

    def build_http_worker_args
      build_generic_proactive_service_args.merge(custom_args)
    end

    def custom_args
    end

    def build_proactive_header
      jwt_payload = { account_id: Account.current.id, sub: 'helpkit', domain: Account.current.full_domain }
      "Token #{sign_payload(jwt_payload)}"
    end

  end
end