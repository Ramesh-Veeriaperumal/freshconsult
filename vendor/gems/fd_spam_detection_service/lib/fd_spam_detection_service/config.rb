module FdSpamDetectionService
  class Config

    attr_writer :global_enable
    attr_accessor :service_url, :timeout

    def global_enable
      @global_enable ||= false
    end

    def self.account_enable(account_id)
    	account = Account.find_by_id(account_id)
      account.make_current
    	unless account.blank? or account.launched?(:spam_detection_service)
        result = FdSpamDetectionService::Service.new(account.id).add_tenant
        if result
          account.launch(:spam_detection_service)
          SpamDetection::DataMigration.perform_async
        end
        Rails.logger.info "Response for adding tenant #{account_id} in SDS: #{result}"
    	end
      Account.reset_current_account
    end

  end
end