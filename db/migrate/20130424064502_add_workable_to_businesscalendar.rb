class AddWorkableToBusinesscalendar < ActiveRecord::Migration
  def self.up
    add_column :business_calendars, :name, :string
    add_column :business_calendars, :description, :string
  	add_column :business_calendars, :time_zone, :string
  	add_column :business_calendars, :is_default, :boolean, :default => false

  	execute("update business_calendars,accounts set business_calendars.time_zone = accounts.time_zone 
  			where accounts.id = business_calendars.account_id")

    execute("update business_calendars set name = 'Default'")

    execute("update business_calendars set description = 'Default Business Calendar'")

    execute("update business_calendars set is_default = true")
  end

  def self.down
  	remove_column :business_calendars, :is_default
  	remove_column :business_calendars, :time_zone
    remove_column :business_calendars, :description
    remove_column :business_calendars, :name
  end
end
