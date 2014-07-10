class AddVersionColumnToBusinessCalendar < ActiveRecord::Migration
  def self.up
    add_column :business_calendars, :version, :integer, :default => 1
  end

  def self.down
    remove_column :business_calendars, :version
  end
end
