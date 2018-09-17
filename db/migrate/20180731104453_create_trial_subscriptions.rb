class CreateTrialSubscriptions < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :trial_subscriptions do |t|
      t.datetime :ends_at
      t.string :from_plan
      t.string :trial_plan
      t.string :result_plan
      t.references :actor
      t.references :account
      t.integer :status
      t.integer :result
      t.string :features_diff

      t.timestamps
    end

    add_index :trial_subscriptions, [:account_id, :status], name: :by_account_status
    add_index :trial_subscriptions, [:status, :ends_at], name: :by_status_ends_at
  end

  def down
    drop_table :trial_subscriptions
  end
end
