module Freshid
  class AccountDetailsUpdate < BaseWorker

    include Redis::RedisKeys
    include Redis::SortedSetRedis
    include Freshid::SnsErrorNotificationExtensions

    sidekiq_options :queue => :freshid_account_details_update, :retry => 0, :failures => :exhausted
    ERROR_ACCOUNT_UPDATE = "FRESHID account details update SQS push error"

    def perform(args)
      args.symbolize_keys!
      args[:destroy].present? ? Freshid::Account.new(args).destroy : Freshid::Account.new(args).update
    rescue Exception => e
      Rails.logger.debug "#{ERROR_ACCOUNT_UPDATE}, #{e.inspect} : #{args.inspect}"
      NewRelic::Agent.notice_error(e, {:args => args})
      notify_error(ERROR_ACCOUNT_UPDATE, args, e)
    end

  end
end