class Freshid::V2::AccountDetailsUpdate < BaseWorker

  include Redis::RedisKeys
  include Redis::SortedSetRedis
  include Freshid::SnsErrorNotificationExtensions

  sidekiq_options :queue => :freshid_account_details_update_v2, :retry => 0, :backtrace => true, :failures => :exhausted
  ERROR_ACCOUNT_UPDATE = "FRESHID V2 account details update SQS push error"

  def perform(args)
    args.symbolize_keys!
    org_domain = args[:organisation_domain]
    freshid_account = Freshid::V2::Models::Account.new({domain: args[:account_domain]})
    response = args[:destroy].present? ? freshid_account.destroy(org_domain) : freshid_account.update(args[:freshid_account_params], org_domain)
    Rails.logger.info "FRESHID V2 ACCOUNT UPDATE/DESTROY :: Args: #{args.inspect} :: Response: #{response.inspect}"
    return unless response.is_error

    loop_counter = args[:loop_counter] ||= 1
    args = {
      method: "update_account",
      error_code: response.code,
      params: args
    }
    FreshidRetryWorker.perform_at((2**loop_counter).minutes.from_now, args)
  rescue Exception => e
    Rails.logger.debug "#{ERROR_ACCOUNT_UPDATE}, #{e.inspect} : #{args.inspect}"
    NewRelic::Agent.notice_error(e, {:args => args})
    notify_error(ERROR_ACCOUNT_UPDATE, args, e)
  end
end