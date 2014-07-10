class AddPreferencesToAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :preferences, :text
  end

  def self.down
    remove_column :accounts, :preferences
  end
end
