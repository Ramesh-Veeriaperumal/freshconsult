class AddNonAvailableMessageToChatSettings < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :chat_settings, :atomic_switch => true do |m|
      m.add_column :non_availability_message, "text"
    end
  end
 
  def self.down
    Lhm.change_table :chat_settings, :atomic_switch => true do |m|
      m.remove_column :non_availability_message
    end
  end
end
