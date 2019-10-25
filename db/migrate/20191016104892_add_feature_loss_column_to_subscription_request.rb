class AddFeatureLossColumnToSubscriptionRequest < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :subscription_requests, atomic_switch: true do |m|
      m.add_column :feature_loss, "tinyint(1) DEFAULT '0'"
    end
  end

  def self.down
    Lhm.change_table :subscription_requests, atomic_switch: true do |m|
      m.remove_column :feature_loss
    end
  end
end