class AddDetailsToEmailNotifications < ActiveRecord::Migration
  def self.up
    add_column :email_notifications, :requester_subject_template, :text
    add_column :email_notifications, :agent_subject_template, :text
  end

  def self.down
    remove_column :email_notifications, :agent_subject_template
    remove_column :email_notifications, :requester_subject_template
  end
end
