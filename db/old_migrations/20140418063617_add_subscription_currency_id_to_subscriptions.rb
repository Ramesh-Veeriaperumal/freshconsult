class AddSubscriptionCurrencyIdToSubscriptions < ActiveRecord::Migration
	shard :all
  
  def self.up
  	Lhm.change_table :subscriptions,:atomic_switch => true do |m|
      m.add_column :subscription_currency_id, "bigint unsigned"
    end
  end

  def self.down
  	Lhm.change_table :subscriptions,:atomic_switch => true do |m|
      m.remove_column :subscriptions
    end
  end
end
