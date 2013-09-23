class ChatAddColumnDisplayId < ActiveRecord::Migration
  shard :none	
  def self.up
  	add_column :chats, :display_id, :text
  end

  def self.down
  	remove_column :chats, :display_id
  end
end
