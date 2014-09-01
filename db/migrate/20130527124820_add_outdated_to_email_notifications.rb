class AddOutdatedToEmailNotifications < ActiveRecord::Migration
	shard :none
  def self.up
  	Lhm.change_table :email_notifications, :atomic_switch => true do |m|
  		m.add_column :outdated_requester_content, "tinyint(1) DEFAULT '0'"
  		m.add_column :outdated_agent_content, "tinyint(1) DEFAULT '0'"
  	end
  end

  def self.down
  	Lhm.change_table :email_notifications, :atomic_switch => true do |m|
  		m.remove_column :outdated_requester_content
  		m.remove_column :outdated_agent_content
  	end
  end
end
