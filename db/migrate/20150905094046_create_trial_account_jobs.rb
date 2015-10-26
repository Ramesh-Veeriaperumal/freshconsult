class CreateTrialAccountJobs < ActiveRecord::Migration
  shard :none
  def self.up
    create_table :trial_account_jobs, :force => true do |t|
      t.integer  :priority, :default => 0
      t.integer  :attempts, :default => 0
      t.text     :handler
      t.text     :last_error
      t.datetime :run_at
      t.datetime :locked_at
      t.datetime :failed_at
      t.string   :locked_by

      t.timestamps
      t.string   :pod_info, :default => 'poduseast1', :null => false
    end

    add_index :trial_account_jobs, :locked_by
    add_index :trial_account_jobs, :pod_info
  end

  def self.down
    drop_table :trial_account_jobs
  end
end
