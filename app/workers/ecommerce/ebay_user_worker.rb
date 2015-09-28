module Ecommerce
  class EbayUserWorker < BaseWorker
    sidekiq_options :queue => :ebay_user_worker, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      begin
        ::Account.reset_current_account
        account_id = args['account_id']
        Sharding.select_shard_of(account_id) do
          account = ::Account.find(account_id)
          account.make_current
          Ecommerce::Ebay::TransactionalUser.new(args).update_user_details
        end
      rescue Exception => e
        Rails.logger.debug "ebay_user_worker::ERROR  => #{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end
  end
end
