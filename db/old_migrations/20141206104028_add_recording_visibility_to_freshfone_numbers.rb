class AddRecordingVisibilityToFreshfoneNumbers < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :recording_visibility, "tinyint(1) DEFAULT 1"
    end
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :recording_visibility
    end
  end
end
