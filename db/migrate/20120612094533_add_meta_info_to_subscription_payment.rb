class AddMetaInfoToSubscriptionPayment < ActiveRecord::Migration
  def self.up
    add_column :subscription_payments, :meta_info, :text
  end

  def self.down
    remove_column :subscription_payments, :meta_info
  end
end
