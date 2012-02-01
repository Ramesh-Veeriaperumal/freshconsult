class RenameOrderColumnsInDayPassPurchases < ActiveRecord::Migration
  def self.up
    rename_column :day_pass_purchases, :order_type, :payment_type
    rename_column :day_pass_purchases, :order_id, :payment_id
  end

  def self.down
    rename_column :day_pass_purchases, :payment_id, :order_id
    rename_column :day_pass_purchases, :payment_type, :order_type
  end
end
