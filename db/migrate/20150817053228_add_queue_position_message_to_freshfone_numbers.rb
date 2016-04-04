class AddQueuePositionMessageToFreshfoneNumbers < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :queue_position_preference, "tinyint(1) DEFAULT 0"
      m.add_column :queue_position_message, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :queue_position_preference
      m.remove_column :queue_position_message
    end
  end
end
