class ChatsAddPreferences < ActiveRecord::Migration
  shard :none	
  def self.up
  	add_column :chats, :preferences, :text
  end

  def self.down
  	remove_column :chats, :preferences
  end
end
