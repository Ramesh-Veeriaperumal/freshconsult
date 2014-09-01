class CreateCustomers < ActiveRecord::Migration
  def self.up
    create_table :customers do |t|
      t.string :name
      t.string :cust_identifier
      t.integer :owner_id
      t.integer :account_id
      t.integer :cust_type
      t.string :phone
      t.string :address
      t.string :website
      t.text :description

      t.timestamps
    end
  end

  def self.down
    drop_table :customers
  end
end
