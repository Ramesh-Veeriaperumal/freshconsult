class AddUserIdToHelpdeskActivities < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_activities, :user_id, :integer
  end

  def self.down
    remove_column :helpdesk_activities, :user_id
  end
end
