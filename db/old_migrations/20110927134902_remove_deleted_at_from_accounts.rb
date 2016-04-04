class RemoveDeletedAtFromAccounts < ActiveRecord::Migration
  def self.up
    remove_column :accounts, :deleted_at
  end

  def self.down
    add_column :accounts, :deleted_at, :datetime
  end
end
