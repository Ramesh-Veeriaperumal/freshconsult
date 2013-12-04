class AddWelcomeMessageAndTypeToFreshfoneIvrs < ActiveRecord::Migration
	shard :none
	def self.up
		add_column :freshfone_ivrs, :welcome_message, :text
		add_column :freshfone_ivrs, :message_type, :integer, :default => 0
	end
 
	def self.down
		remove_column :freshfone_ivrs, :message_type
		remove_column :freshfone_ivrs, :welcome_message
	end
end