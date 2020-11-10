module FdSpamDetectionService
  class Config

    attr_writer :global_enable
    attr_accessor :service_url, :timeout, :outgoing_block_mrr_threshold, :api_key

    def global_enable
      @global_enable ||= false
    end

    def self.account_enable(account_id)
    	account = Account.find_by_id(account_id)
      account.make_current
      if account.present?
        result = FdSpamDetectionService::Service.new(account.id).add_tenant
        if result
          SpamDetection::DataMigration.perform_async
        end
        Rails.logger.info "Response for adding tenant #{account_id} in SDS: #{result}"
    	end
      Account.reset_current_account
    end

  end
end
