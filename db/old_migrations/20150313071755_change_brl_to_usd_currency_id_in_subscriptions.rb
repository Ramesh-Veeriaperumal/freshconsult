class ChangeBrlToUsdCurrencyIdInSubscriptions < ActiveRecord::Migration
  shard :all
  def self.up
    usd_currency = Subscription::Currency.find_by_name("USD")
    brl_currency_id = Subscription::Currency.find_by_name("BRL").id
    Subscription.skip_callback(:update)
    Sharding.run_on_all_shards do
      Subscription.find(:all, :conditions => ["state != ? and subscription_currency_id = ?", "active", brl_currency_id]).each do |subscription|
        subscription.currency = usd_currency
        subscription.send(:update)
      end
    end
    Subscription.reset_callbacks :update
  end

  def self.down

  end
end
