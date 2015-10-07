module Ecommerce
  class EbayWorker < BaseWorker

    sidekiq_options :queue => :ebay_worker, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      begin
        ::Account.reset_current_account
        account_id = args['account_id']
        Sharding.select_shard_of(account_id) do
          account = ::Account.find(account_id)
          account.make_current
          ebay_processor = Ecommerce::Ebay::Processor.new(args)
          return if ebay_processor.ebay_account.blank? and !ebay_processor.ebay_account.active?
          ticket = ebay_processor.check_parent_ticket(ebay_processor.notification_user.id, ebay_processor.notification_subject, ebay_processor.notification_item_id)
          ticket ? ebay_processor.thread_exists(ticket) : ebay_processor.thread_not_exists
          Rails.logger.debug "Notification processed with params #{args} "
        end
      rescue Exception => e
        Rails.logger.debug "ebay_worker::ERROR  => #{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end

  end
end