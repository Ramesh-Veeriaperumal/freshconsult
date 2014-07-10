class CreateEmailNotifications < ActiveRecord::Migration
  def self.up
    create_table :email_notifications do |t|
      t.integer :type
      t.integer :account_id
      t.boolean :requester_notification
      t.text :requester_template
      t.boolean :agent_notification
      t.text :agent_template

      t.timestamps
    end
  end

  def self.down
    drop_table :email_notifications
  end
end
