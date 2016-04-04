class AddBusinessCalendarIdToChatSettings < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :chat_settings, :atomic_switch => true do |m|
    m.add_column :business_calendar_id, "bigint"
  end
  end

  def self.down
    Lhm.change_table :chat_settings, :atomic_switch => true do |m|
    m.remove_column :business_calendar_id
  end
  end
end
