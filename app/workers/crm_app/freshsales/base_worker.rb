class CRMApp::Freshsales::BaseWorker < BaseWorker

  sidekiq_options :queue => :track_customer_in_freshsales, :retry => 5,
    :failures => :exhausted

  def prepare_subscription(subscription_args)
    subscription_info = subscription_args.symbolize_keys
    subscription_info[:amount] = subscription_info[:amount].to_f
    subscription_info[:created_at] = DateTime.parse(subscription_info[:created_at])
    subscription_info
  end

  def freshsales_utility(args, account)
    account_subscription = account.subscription
    subscription = args[:subscription].present? ? 
      prepare_subscription(args[:subscription]) : account_subscription.attributes.symbolize_keys
    cmrr = args[:cmrr].present? ? args[:cmrr].to_f : account_subscription.cmrr
    CRM::FreshsalesUtility.new({ 
      account: account, 
      subscription: subscription, 
      cmrr: cmrr 
    })
  end

  def execute_on_shard(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      yield
    end
  end
end
