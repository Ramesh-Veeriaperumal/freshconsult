class CreateDeletedCustomers < ActiveRecord::Migration
  def self.up
    create_table :deleted_customers do |t|
      t.string :full_domain
      t.integer :account_id, :unique => true
      t.string :admin_name
      t.string :admin_email
      t.text :account_info
      t.timestamps
    end
  end

  def self.down
    drop_table :deleted_customers
  end
end
