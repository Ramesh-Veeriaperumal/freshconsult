class FixBusinessCalHolName < ActiveRecord::Migration
  def self.up
     rename_column :business_calendars, :holidays, :holiday_data
  end

  def self.down
     rename_column :business_calendars, :holiday_data, :holidays
  end
end
