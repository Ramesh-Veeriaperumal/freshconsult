class AddNotificationTypeAndTitleToSubscriptionAnnouncements < ActiveRecord::Migration
	shard :shard_1
	
  def self.up
    add_column :subscription_announcements, :title, :text, :null => false
    add_column :subscription_announcements, :notification_type, :integer, :null => false, :default => 1
    add_column :subscription_announcements, :url, :text, :null => false
  end

  def self.down
    remove_column :subscription_announcements, :url
    remove_column :subscription_announcements, :notification_type
    remove_column :subscription_announcements, :title
  end
end
