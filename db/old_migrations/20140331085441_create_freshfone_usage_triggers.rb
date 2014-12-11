class CreateFreshfoneUsageTriggers < ActiveRecord::Migration
  shard :all

  def self.up
    create_table :freshfone_usage_triggers do |t|
      t.integer  :account_id, :limit => 8
      t.integer  :freshfone_account_id, :limit => 8
      t.integer  :trigger_type
      t.string   :sid, :limit => 50
      t.integer  :start_value
      t.integer  :trigger_value
      t.integer  :fired_value
      t.string   :idempotency_token, :limit => 100

      t.timestamps
    end
    add_index(:freshfone_usage_triggers, [:account_id, :sid])
    add_index(:freshfone_usage_triggers, [:account_id, :created_at, :trigger_type], 
      :name => "index_ff_usage_triggers_account_created_at_type")
  end

  def self.down
    drop_table :freshfone_usage_triggers
  end
end