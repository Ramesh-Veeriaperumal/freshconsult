class AddJobIdAccountIdColumnToDelayedJobs < ActiveRecord::Migration
  shard :none
  def migrate(direction)
    self.send(direction)
  end

  def up
  	Lhm.change_table :delayed_jobs, :atomic_switch => true do |m|
      m.add_column :sidekiq_job_info, 'varchar(255) DEFAULT NULL'
      m.add_column :account_id, "bigint unsigned DEFAULT NULL"
      m.add_index [:account_id], 'index_delayed_jobs_on_account_id'
    end
    Lhm.change_table :mailbox_jobs, :atomic_switch => true do |m|
      m.add_column :sidekiq_job_info, 'varchar(255) DEFAULT NULL'
      m.add_column :account_id, "bigint unsigned DEFAULT NULL"
      m.add_index [:account_id], 'index_mailbox_jobs_on_account_id'
    end
    Lhm.change_table :active_account_jobs, :atomic_switch => true do |m|
      m.add_column :sidekiq_job_info, 'varchar(255) DEFAULT NULL'
      m.add_column :account_id, "bigint unsigned DEFAULT NULL"
      m.add_index [:account_id], 'index_active_account_jobs_on_account_id'
    end
    Lhm.change_table :free_account_jobs, :atomic_switch => true do |m|
      m.add_column :sidekiq_job_info, 'varchar(255) DEFAULT NULL'
      m.add_column :account_id, "bigint unsigned DEFAULT NULL"
      m.add_index [:account_id], 'index_free_account_jobs_on_account_id'
    end
    Lhm.change_table :trial_account_jobs, :atomic_switch => true do |m|
      m.add_column :sidekiq_job_info, 'varchar(255) DEFAULT NULL'
      m.add_column :account_id, "bigint unsigned DEFAULT NULL"
      m.add_index [:account_id], 'index_trial_account_jobs_on_account_id'
    end
    Lhm.change_table :premium_account_jobs, :atomic_switch => true do |m|
      m.add_column :sidekiq_job_info, 'varchar(255) DEFAULT NULL'
      m.add_column :account_id, "bigint unsigned DEFAULT NULL"
      m.add_index [:account_id], 'index_premium_account_jobs_on_account_id'
    end
  end

  def down
  	Lhm.change_table :delayed_jobs, :atomic_switch => true do |m|
      m.remove_index :account_id
      m.remove_column :sidekiq_job_info
      m.remove_column :account_id
    end
    Lhm.change_table :active_account_jobs, :atomic_switch => true do |m|
      m.remove_index :account_id
      m.remove_column :sidekiq_job_info
      m.remove_column :account_id
    end
    Lhm.change_table :mailbox_jobs, :atomic_switch => true do |m|
      m.remove_index :account_id
      m.remove_column :sidekiq_job_info
      m.remove_column :account_id
    end
    Lhm.change_table :free_account_jobs, :atomic_switch => true do |m|
      m.remove_index :account_id
      m.remove_column :sidekiq_job_info
      m.remove_column :account_id
    end
    Lhm.change_table :trial_account_jobs, :atomic_switch => true do |m|
      m.remove_index :account_id
      m.remove_column :sidekiq_job_info
      m.remove_column :account_id
    end
    Lhm.change_table :premium_account_jobs, :atomic_switch => true do |m|
      m.remove_index :account_id
      m.remove_column :sidekiq_job_info
      m.remove_column :account_id
    end
  end
end
