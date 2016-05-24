class AlterDisplayIdToSiteIdInChatSettings < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def self.up
    execute("alter table chat_settings change display_id site_id varchar(255) DEFAULT NULL ;")
  end

  def self.down
    execute("alter table chat_settings change site_id display_id varchar(255) DEFAULT NULL ;")
  end
end
