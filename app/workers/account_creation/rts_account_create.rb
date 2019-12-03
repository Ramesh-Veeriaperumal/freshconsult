module AccountCreation
  class RTSAccountCreate < BaseWorker
    include RTS::Constants

    sidekiq_options queue: :rts_account_create, retry: 1, failures: :exhausted

    def perform
      acc = Account.current
      raise 'Account is not present' if acc.blank?

      service_response = make_rts_http_call
      if SUCCESS_CODES.include?(service_response[:status])
        data = JSON.parse(service_response[:text])
        acc_add_settings = acc.account_additional_settings
        acc_add_settings.additional_settings[:rts_account_id] = data['accId']
        acc_add_settings.assign_rts_account_secret(data['key'])
        acc_add_settings.save
      else
        Rails.logger.info "Received failure response from the RTS account register #{service_response.inspect}"
      end
    rescue StandardError => e
      Rails.logger.error "Error when creating the RTS Account #{e.message}"
      NewRelic::Agent.notice_error(e)
      raise e
    end

    def make_rts_http_call
      hrp = HttpRequestProxy.new
      service_params = {
        domain: RTSConfig['end_point'],
        rest_url: RTS_ACCOUNT_REGISTER[:end_point],
        body: payload.to_json
      }
      request_params = { method: RTS_ACCOUNT_REGISTER[:http_method] }
      hrp.fetch_using_req_params(service_params, request_params)
    end

    def payload
      {
        name: Account.current.id.to_s,
        version: RTS_ACCOUNT_REGISTER[:default_version],
        desc: format(RTS_ACCOUNT_REGISTER[:default_description], account_name: Account.current.name)
      }
    end
  end
end
