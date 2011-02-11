class AddShortDescrToHelpdeskActivities < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_activities, :short_descr, :text
  end

  def self.down
    remove_column :helpdesk_activities, :short_descr
  end
end
