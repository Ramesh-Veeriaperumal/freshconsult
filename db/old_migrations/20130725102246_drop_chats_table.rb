class DropChatsTable < ActiveRecord::Migration
  shard :none
  def self.up
  	drop_table :chats
  end

  def self.down
  end
end
