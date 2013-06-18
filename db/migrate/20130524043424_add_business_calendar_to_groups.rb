class AddBusinessCalendarToGroups < ActiveRecord::Migration
	shard :none
  def self.up
  	Lhm.change_table :groups, :atomic_switch => true do |m|
  		m.add_column :groups, :business_calendar_id, :integer
  	end

  	execute("update groups,business_calendars set groups.business_calendar_id = business_calendars.id 
  	 		where groups.account_id = business_calendars.account_id;")
  end

  def self.down
  	Lhm.change_table :groups, :atomic_switch => true do |m|
  		m.remove_column :business_calendar_id
  	end
  end
end
