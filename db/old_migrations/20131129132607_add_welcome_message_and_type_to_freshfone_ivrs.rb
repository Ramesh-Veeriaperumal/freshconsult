class AddWelcomeMessageAndTypeToFreshfoneIvrs < ActiveRecord::Migration
	shard :none
	def self.up
		Lhm.change_table :freshfone_ivrs, :atomic_switch => true do |m|
      m.add_column :welcome_message, "text COLLATE utf8_unicode_ci"
      m.add_column :message_type, "int(11) DEFAULT 0"
    end
	end
 
	def self.down
		Lhm.change_table :freshfone_ivrs, :atomic_switch => true do |m|
			m.remove_column :welcome_message
			m.remove_column :message_type
		end
	end
end