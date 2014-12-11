class AddPremiumToAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :premium, :boolean, :default => false
  end

  def self.down
    remove_column :accounts, :premium
  end
end
