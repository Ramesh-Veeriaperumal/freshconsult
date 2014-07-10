class RemoveHolidayDataFromBusinessCalendar < ActiveRecord::Migration
  def self.up
    remove_column :business_calendars, :holiday_data
    add_column :business_calendars, :holidays, :text
  end

  def self.down
    remove_column :business_calendars, :holidays
    add_column :business_calendars, :holiday_data, :text
  end
end
