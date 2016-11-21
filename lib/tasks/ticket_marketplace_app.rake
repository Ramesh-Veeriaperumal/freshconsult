namespace :ticket_marketplace_app do

  desc "Timeout and running dispatcher for tickets sent for enrichment."
  task :run_dispatcher => :environment do

    include Redis::MarketplaceAppRedis
    MARKETPLACE_APP_TIMEOUT = 35.seconds

    while(true) do
      account_ids = LaunchParty.new.accounts_for(:synchronous_apps)
      account_ids.each do |account_id|
        tkt_tokens = ticket_tokens(account_id)
        next if tkt_tokens.blank?
        Sharding.select_shard_of(account_id) do
          Sharding.run_on_slave do
            a = Account.find(account_id).make_current
            tkt_tokens.each do |ticket_token|
              Rails.logger.info "Enqueued dispatcher for account_id :: #{account_id} :: Ticket #{ticket_token}"
              Helpdesk::QueueDispatcher.new(ticket_token).perform
            end
            Account.reset_current_account
          end
        end
      end
      sleep(30.seconds)
    end
  end

  def ticket_tokens_count account_id
    count_marketplace_app_redis_key(detail_key(account_id))
  end

  def ticket_tokens account_id
    return [] if ticket_tokens_count(account_id) == 0
    sorted_range_marketplace_app_redis_key(detail_key(account_id), 0, Time.now.to_i - MARKETPLACE_APP_TIMEOUT)
  end

end