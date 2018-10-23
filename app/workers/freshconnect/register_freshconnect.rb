module Freshconnect
  class RegisterFreshconnect < BaseWorker
    sidekiq_options queue: :register_freshconnect, retry: 0, backtrace: true, failures: :exhausted

    SUCCESS = 200..299

    def perform
      actual_response = register_with_freshconnect
      response_code = actual_response.code
      if SUCCESS.include?(response_code)
        response = JSON.parse(actual_response.body)
        response = response.deep_symbolize_keys
        fresh_connect_acc = create_account_instance(response)
        fresh_connect_acc.save!
        account.add_feature(:freshconnect)
        Rails.logger.info "Successfull Registration with Freshconnect for AccountId #{account.id}. Response: #{response}"
      else
        Rails.logger.error "Failed Registration with Freshconnect for AccountId #{account.id}. Response: #{actual_response.body}, #{response_code}"
      end
    rescue Exception => e
      Rails.logger.error "Error while enabling Freshconnect for AccountId #{account.id}. Exception:: #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Error while enabling Freshconnect for AccountId #{account.id}")
    end

    private
      def register_with_freshconnect
        RestClient::Request.execute(
          method: :post,
          url: CollabConfig['freshconnect_endpoint'],
          payload: {
            domain: account.full_domain,
            account_id: account.id.to_s,
            enabled: true
          }.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'ProductName' => 'freshdesk',
            'Authorization' => collab_request_token
          }
        )
      end

      def collab_request_token
        @request_token ||= JWT.encode(
          {
            ProductAccountId: '',
            IsServer: '1'
          }, CollabConfig['secret_key']
        )
      end

      def create_account_instance(response)
        Freshconnect::Account.new(account_id: account.id,
                                  product_account_id: response[:product_account_id],
                                  enabled: response[:enabled],
                                  freshconnect_domain: response[:domain])
      end

      def account
        ::Account.current
      end
  end
end
