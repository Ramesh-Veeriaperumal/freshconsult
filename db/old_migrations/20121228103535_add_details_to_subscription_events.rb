class AddDetailsToSubscriptionEvents < ActiveRecord::Migration
  def self.up
    drop_table :subscription_events
    
    create_table :subscription_events do |t|
      t.column    "account_id", "bigint unsigned"
      t.integer   "code"
      t.text      "info"
      t.integer   "subscription_plan_id"
      t.integer   "renewal_period"
      t.integer   "total_agents"
      t.integer   "free_agents"
      t.integer   "subscription_affiliate_id"
      t.integer   "subscription_discount_id"
      t.boolean   "revenue_type"
      t.decimal   "cmrr",  :precision => 10, :scale => 2

      t.timestamps
    end
  end

  def self.down
    drop_table :subscription_events

    create_table :subscription_events do |t|
      t.integer   "account_id"
      t.string    "code"
      t.text      "info"

      t.timestamps
    end
  end
end
