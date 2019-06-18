class BlockAccount < BaseWorker
  sidekiq_options queue: :block_account, retry: 3,  failures: :exhausted

  RECIPIENTS = ['fd-shadowfax@freshdesk.com'].freeze
  def perform(args)
    args.symbolize_keys!
    Sharding.admin_select_shard_of(args[:account_id]) do
      account = Account.find(args[:account_id]).make_current
      return unless account_blockable?
      shard_mapping = ShardMapping.find(args[:account_id])
      shard_mapping.status = ShardMapping::STATUS_CODE[:blocked]
      shard_mapping.save!
      $spam_watcher.perform_redis_op('del', "#{account.id}-")
      SearchService::Client.new(account.id).tenant_suspend
      Fdadmin::APICalls.make_api_request_to_global(:post, url_params,
                                                   AdminApiConfig[Rails.env]['activity_url'],
                                                   AdminApiConfig[Rails.env]['url'].sub(/^https?\:\/\//,'')[0..-2])
      #Removing protocol part from url as it's explicitly prepended in make_api_request_to_global. Removed trailing backslash as the path includes that already
      #Need to revisit fdadmin_api_config
    end
  end

  private

    def url_params
      { app_name: 'helpkit',
        activity: {
          email: AppConfig['from_email'],
          reason: 'Blocked due to inactivity',
          action_name: 'block_account',
          account_id: Account.current.id.to_s,
          account_name: Account.current.name.to_s
        } }
    end

    def billing_cancel_date
      billing_data = Billing::Subscription.new.retrieve_subscription(Account.current.id)
      Time.at(billing_data.subscription.cancelled_at).to_datetime.utc
    end

    def account_blockable?
      cancel_date = billing_cancel_date
      block_account = (Account.current.subscription.suspended?) && (Time.now > (cancel_date + Account::BLOCK_GRACE_PERIOD - 5.days))
      unless block_account
        error_log = "**** Account block failed: Account Id: #{Account.current.id}  Subscription state: #{Account.current.subscription.state} Billing Cancel Date: #{cancel_date}"
        Rails.logger.debug(error_log)
        FreshdeskErrorsMailer.error_email(nil, { 'domain_name' => Account.current.full_domain }, error_log, subject: error_log, recipients: RECIPIENTS)
      end
      block_account
    end
end
