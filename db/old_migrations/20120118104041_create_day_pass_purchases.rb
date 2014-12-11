class CreateDayPassPurchases < ActiveRecord::Migration
  def self.up
    create_table :day_pass_purchases do |t|
      t.column :account_id, "bigint unsigned"
      t.integer :paid_with
      t.string :order_type
      t.column :order_id, "bigint unsigned"
      t.integer :status
      t.integer :quantity_purchased

      t.timestamps
    end
  end

  def self.down
    drop_table :day_pass_purchases
  end
end
