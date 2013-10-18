class AddIsTypingColumnToChat < ActiveRecord::Migration
  shard :none	
  def self.up
  	add_column :chats, :is_typing, :text
  end

  def self.down
  	remove_column :chats, :is_typing
  end
end
