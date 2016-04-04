class CreateMailboxJobs < ActiveRecord::Migration
  shard :none
  def self.up
    create_table :mailbox_jobs, :force => true do |t|
      t.integer  :priority, :default => 0
      t.integer  :attempts, :default => 0
      t.text     :handler
      t.text     :last_error
      t.datetime :run_at
      t.datetime :locked_at
      t.datetime :failed_at
      t.string   :locked_by

      t.timestamps
    end

    add_index :mailbox_jobs, :locked_by
  end

  def self.down
    drop_table :mailbox_jobs
  end
end
