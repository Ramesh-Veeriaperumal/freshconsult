class CreateAccountConfigurations < ActiveRecord::Migration
  
  def self.up
    create_table :account_configurations do |t|
      t.column  "account_id", "bigint unsigned", :unique => true, :null => false 
      t.text :contact_info
      t.text  :billing_emails

      t.timestamps
    end
  end

  def self.down
  	drop_table :account_configurations
  end

end
