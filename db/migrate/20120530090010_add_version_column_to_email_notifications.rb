class AddVersionColumnToEmailNotifications < ActiveRecord::Migration
  def self.up
    add_column :email_notifications, :version, :integer, :default => 1
  end

  def self.down
    remove_column :email_notifications, :version
  end
end
