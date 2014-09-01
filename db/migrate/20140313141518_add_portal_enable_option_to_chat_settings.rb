class AddPortalEnableOptionToChatSettings < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :chat_settings, :atomic_switch => true do |m|
      m.add_column :show_on_portal, "tinyint(1) DEFAULT '1'"
      m.add_column :portal_login_required,"tinyint(1) DEFAULT '0'"
    end
  end
 
  def self.down
    Lhm.change_table :chat_settings, :atomic_switch => true do |m|
      m.remove_column :show_on_portal
      m.remove_column :portal_login_required
    end
  end
end
