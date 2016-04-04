class AddRecordingDeletedToFreshfoneCalls < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_column :recording_deleted, "tinyint(1) DEFAULT '0'"
      m.add_column :recording_deleted_info, "text DEFAULT NULL"
      m.add_index :id,'index_ff_calls_on_id'
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_column :recording_deleted
      m.remove_column :recording_deleted_info
      m.remove_index :id,'index_ff_calls_on_id'
    end
  end
end