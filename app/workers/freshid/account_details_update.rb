module Freshid
  class AccountDetailsUpdate < BaseWorker

    include Redis::RedisKeys
    include Redis::SortedSetRedis

    sidekiq_options :queue => :freshid_account_details_update, :retry => 3, :backtrace => true, :failures => :exhausted
    DESCRIPTION = "Freshid account details update SQS push error"

    def perform(args)
      args.symbolize_keys!
      args[:destroy].present? ? Freshid::Account.new(args).destroy : Freshid::Account.new(args).update

    rescue Exception => e
      Rails.logger.debug "FRESHID Error while updating account information, #{e.inspect} : #{args.inspect}"
      NewRelic::Agent.notice_error(e, {:args => args})
      DevNotification.publish(SNS["freshid_notification_topic"], DESCRIPTION, args.to_json)
    end

  end
end