class CreateSubscriptionRequests < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :subscription_requests do |t|
      t.integer :id, limit: 8, null: false
      t.integer :plan_id, limit: 8
      t.integer :agent_limit
      t.integer :renewal_period
      t.integer :account_id, limit: 8
      t.integer :subscription_id, limit: 8
      t.integer :fsm_field_agents

      t.timestamps
    end

    add_index :subscription_requests, [:account_id, :subscription_id], name: 'index_subscription_requests_on_account_id_subscription_id'
  end

  def down
    drop_table :subscription_requests
  end
end
