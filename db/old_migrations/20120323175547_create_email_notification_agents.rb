class CreateEmailNotificationAgents < ActiveRecord::Migration
  def self.up
    create_table :email_notification_agents do |t|
      t.column :email_notification_id, "bigint unsigned"
      t.column :user_id, "bigint unsigned"
      t.column :account_id, "bigint unsigned"
      
      t.timestamps
    end
    add_index :email_notification_agents, [:account_id, :email_notification_id], :name => 'index_email_notification_agents_on_acc_and_email_notification_id'
  end

  def self.down
    drop_table :email_notification_agents   
  end
end