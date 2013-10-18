class ChatsAddColumn < ActiveRecord::Migration
  shard :none
  def self.up
	execute("alter table chats add column prechat_form int(11) DEFAULT 0,
  	 	add column proactive_chat int(11) DEFAULT 0")
  end

  def self.down
  	execute("alter table chats drop column prechat_form,
  	 	drop column proactive_chat")
  end
end
