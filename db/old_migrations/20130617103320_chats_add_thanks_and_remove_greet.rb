class ChatsAddThanksAndRemoveGreet < ActiveRecord::Migration
  shard :none
  def self.up
  	execute("alter table chats add column thank_msg varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  	 	drop column prechat_name,
  	 	drop column greet_msg")
  end

  def self.down
  	execute("alter table chats drop column thank_msg,
  	 	add column prechat_name int(11) DEFAULT NULL,
  	 	add column greet_msg varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL")
  end
end