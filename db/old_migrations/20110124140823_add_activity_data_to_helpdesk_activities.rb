class AddActivityDataToHelpdeskActivities < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_activities, :activity_data, :text
  end

  def self.down
    remove_column :helpdesk_activities, :activity_data
  end
end
