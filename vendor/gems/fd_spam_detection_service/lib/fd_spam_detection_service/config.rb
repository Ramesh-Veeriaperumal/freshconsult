module FdSpamDetectionService
  class Config

    attr_writer :global_enable
    attr_accessor :service_url, :timeout

    def global_enable
      @global_enable ||= false
    end

    def self.account_enable(account_id)
    	account = Account.find_by_id(account_id)
    	unless account.blank? or account.launched?(:spam_detection_service)
    		account.launch(:spam_detection_service)
    		result = FdSpamDetectionService::Service.new(account.id).add_tenant
        Rails.logger.info "Response for adding tenant in SDS: #{result}"
    	end
    end

  end
end