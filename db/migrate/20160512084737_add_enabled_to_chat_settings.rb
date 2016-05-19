class AddEnabledToChatSettings < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def self.up
    Lhm.change_table :chat_settings, :atomic_switch => true do |m|
      m.add_column :enabled, "tinyint(1) DEFAULT 0"
    end

    execute("update chat_settings set enabled = active;")

    execute("update chat_settings set active = IF(display_id=NULL, 0, 1);")
  end

  def self.down
  	execute("update chat_settings set active = enabled;")
    Lhm.change_table :chat_settings, :atomic_switch => true do |m|
      m.remove_column :enabled
    end
  end
end
