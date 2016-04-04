class CreateSubscriptionEvents < ActiveRecord::Migration
  
  def self.up
  	create_table :subscription_events do |t|
      t.integer   "account_id"
      t.string    "code"
      t.text      "info"
 
      t.timestamps
    end
  end

  def self.down
    drop_table :subscription_events
  end
end
