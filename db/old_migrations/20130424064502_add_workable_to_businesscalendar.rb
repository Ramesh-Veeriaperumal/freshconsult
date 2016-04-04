class AddWorkableToBusinesscalendar < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :business_calendars, :atomic_switch => true do |m|
      m.add_column :name, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
      m.add_column :description, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
      m.add_column :time_zone, "varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL"
      m.add_column :is_default, "tinyint(1) DEFAULT '0'"
    end

  	execute("update business_calendars,accounts set business_calendars.time_zone = accounts.time_zone 
  			where accounts.id = business_calendars.account_id")

    execute("update business_calendars set name = 'Default'")

    execute("update business_calendars set description = 'Default Business Calendar'")

    execute("update business_calendars set is_default = true")
  end

  def self.down
  	Lhm.change_table :business_calendars, :atomic_switch => true do |m|
      m.remove_column :name
      m.remove_column :description
      m.remove_column :time_zone
      m.remove_column :is_default
    end
  end
end
