class CreateDynamicNotificationTemplates < ActiveRecord::Migration
	shard :none
  def self.up
  	create_table :dynamic_notification_templates do |t|
			t.column :account_id ,'bigint unsigned'
			t.column :email_notification_id , 'bigint unsigned'
			t.integer :category
			t.integer :language
			t.text :description
			t.text :subject
			t.boolean :outdated
			t.boolean :active 
			t.timestamps
		end		
	end

  def self.down
  	drop_table :dynamic_notification_templates
  end
end
