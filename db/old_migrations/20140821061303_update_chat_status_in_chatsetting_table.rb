class UpdateChatStatusInChatsettingTable < ActiveRecord::Migration
  shard :all
  def self.up
  	add_column :chat_settings, :active, :boolean , default: 0
	end

  def self.down
  	remove_column :chat_settings, :active
  end
end
