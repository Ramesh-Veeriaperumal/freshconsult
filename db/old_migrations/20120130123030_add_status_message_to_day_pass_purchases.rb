class AddStatusMessageToDayPassPurchases < ActiveRecord::Migration
  def self.up
    add_column :day_pass_purchases, :status_message, :string
  end

  def self.down
    remove_column :day_pass_purchases, :status_message
  end
end
