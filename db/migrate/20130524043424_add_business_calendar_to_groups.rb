class AddBusinessCalendarToGroups < ActiveRecord::Migration
	shard :none
  def self.up
  	 add_column :groups, :business_calendar_id, :integer

  	 execute("update groups,business_calendars set groups.business_calendar_id = business_calendars.id 
  	 		where groups.account_id = business_calendars.account_id;")
  end

  def self.down
  	remove_column :groups, :business_calendar_id
  end
end
