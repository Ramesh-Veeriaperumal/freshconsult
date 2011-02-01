class RemoveTypeFromEmailNotifications < ActiveRecord::Migration
  def self.up
    remove_column :email_notifications, :type
    add_column :email_notifications, :notification_type, :integer
  end

  def self.down
    remove_column :email_notifications, :notification_type
    add_column :email_notifications, :type, :integer
  end
end
