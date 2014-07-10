class AddTimeZoneToAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :time_zone, :string
    add_column :users, :time_zone, :string
  end

  def self.down
    remove_column :users, :time_zone
    remove_column :accounts, :time_zone
  end
end
