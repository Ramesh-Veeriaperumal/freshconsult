class AddAccountIdToHelpdeskSubscriptions < ActiveRecord::Migration
  def self.up
  	add_column :helpdesk_subscriptions, :account_id, "bigint unsigned"
  end

  def self.down
  	remove_column :helpdesk_subscriptions, :account_id
  end
end
