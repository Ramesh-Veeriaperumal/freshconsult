module Freshconnect
  class UpdateFreshconnect < BaseWorker
    sidekiq_options queue: :update_freshconnect, retry: 15, backtrace: true, failures: :exhausted

    MAX_INTERVAL_MINUTES = 240
    SUCCESS = 200..299

    sidekiq_retry_in do |count|
      next_retry = ((count + 1) * 30 > MAX_INTERVAL_MINUTES ? MAX_INTERVAL_MINUTES : (count + 1) * 30)
      next_retry.minutes
    end

    def perform(enabled)
      @account = ::Account.current
      response = freshconnect_update(enabled)
      raise "Failed response. Response: #{response.body}, #{response.code}" unless SUCCESS.include?(response.code)
      response = JSON.parse(response.body)
      response.deep_symbolize_keys!
      @account.freshconnect_account.update_attributes(enabled: response[:enabled])
      Rails.logger.info "Successfull Updation on Freshconnect for AccountId #{@account.id}...#{response}"
    rescue Exception => e
      Rails.logger.error "Error while updating Freshconnect for AccountId #{@account.id}...Exception:: #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Error while updating Freshconnect for AccountId #{@account.id}")
      raise e
    end

    private

      def freshconnect_update(enabled)
        @product_acc_id = @account.freshconnect_account.product_account_id
        RestClient::Request.execute(
          method: :put,
          url: CollabConfig['freshconnect_endpoint'],
          payload: {
            id: @product_acc_id,
            enabled: enabled
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
            ProductAccountId: @product_acc_id,
            IsServer: '1'
          }, CollabConfig['secret_key']
        )
      end
  end
end
