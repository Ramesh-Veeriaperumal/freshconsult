class CreateBusinessCalendars < ActiveRecord::Migration
  def self.up
    create_table :business_calendars do |t|
      t.integer :account_id
      t.text :business_time_data
      t.text :holiday_data

      t.timestamps
    end
  end

  def self.down
    drop_table :business_calendars
  end
end
