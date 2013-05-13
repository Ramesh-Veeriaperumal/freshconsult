class AddWorkableToBusinesscalendar < ActiveRecord::Migration
  def self.up
    add_column :business_calendars, :name, :string, :default => 'Default'
    add_column :business_calendars, :description, :string, :default => 'Default Business Calendar'
  	add_column :business_calendars, :workable_id, "bigint unsigned"
  	add_column :business_calendars, :workable_type, :string, :default => 'Account'
  	add_column :business_calendars, :time_zone, :string
  	add_column :business_calendars, :is_default, :boolean, :default => false

  	execute("update business_calendars,accounts set business_calendars.time_zone = accounts.time_zone 
  			where accounts.id = business_calendars.account_id")

  	execute("update business_calendars set workable_id = account_id")
  end

  def self.down
  	remove_column :business_calendars, :is_default
  	remove_column :business_calendars, :time_zone
  	remove_column :business_calendars, :workable_type
  	remove_column :business_calendars, :workable_id
    remove_column :business_calendars, :description
    remove_column :business_calendars, :name
  end
end
