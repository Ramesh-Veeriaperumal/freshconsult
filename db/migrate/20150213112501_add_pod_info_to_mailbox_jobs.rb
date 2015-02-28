class AddPodInfoToMailboxJobs < ActiveRecord::Migration

  shard :all

  def self.up
    Lhm.change_table :mailbox_jobs, :atomic_switch => true do |m|
      m.add_column :pod_info, "varchar(255) COLLATE utf8_unicode_ci DEFAULT 'poduseast'"
      m.add_index :pod_info
    end
  end

  def self.down
    Lhm.change_table :mailbox_jobs, :atomic_switch => true do |m|
      m.remove_column :pod_info
    end
  end
end
