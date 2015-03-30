class Workers::Ecommerce::Ebay::ValidateAccount
  extend Resque::AroundPerform 
  

  @queue = 'validate_ebay_account'

  class << self

    include Ecommerce::Ebay::Util
    include Ecommerce::Constants

    def perform args
      begin
        if args[:retry_count].present?
          return unless args[:retry_count] < EBAY_MAXIMUM_RETRY
        end
        ebay_account = Account.current.ebay_accounts.find_by_id(args[:ecommerce_account_id])
        obj = Ecommerce::Ebay::Api.new(ebay_account.id)
        acc_details = obj.make_call(:check_account_status)
        return handle_retry(args) if obj.instance_variable_get(:@retry) 
        if acc_details && ((ebay_account.external_account_id == acc_details[:account_id]) or (!account_exists?(acc_details[:account_id])))
          ebay_account.activate_account(acc_details[:account_id])  
          ebay_account.reload
          EcommerceNotifier.send_later(:deliver_account_activation, ebay_account.name, Account.current) if ebay_account.active
        else
          ebay_account.deactivate_account
          ebay_account.reload
          EcommerceNotifier.send_later(:deliver_invalid_account, ebay_account.name, Account.current) unless ebay_account.active
        end
      rescue Exception => e
        Rails.logger.debug "ValidateEbayAccount::ERROR  => #{e.message}"
      end
    end

    private
      def handle_retry args
        args[:retry_count] = args[:retry_count].to_i + 1
        Resque.enqueue_in(EBAY_SCHEDULE_AFTER, Workers::Ecommerce::Ebay::ValidateAccount, args)
      end

  end

end
