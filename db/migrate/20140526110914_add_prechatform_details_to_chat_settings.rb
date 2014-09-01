class AddPrechatformDetailsToChatSettings < ActiveRecord::Migration
  shard :all
  def self.up
  	Lhm.change_table :chat_settings, :atomic_switch => true do |m|
      m.add_column :prechat_form_name, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
      m.add_column :prechat_form_mail, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
      m.add_column :prechat_form_phoneno, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
    end
  end

  def self.down
  	Lhm.change_table :chat_settings, :atomic_switch => true do |m|
      m.remove_column :prechat_form_name
      m.remove_column :prechat_form_mail
      m.remove_column :prechat_form_phoneno
    end
  end
end
