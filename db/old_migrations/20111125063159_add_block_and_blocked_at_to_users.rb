class AddBlockAndBlockedAtToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :blocked, :boolean, :default => false
    add_column :users, :blocked_at, :datetime
  end

  def self.down
    remove_column :users, :blocked_at
    remove_column :users, :blocked
  end
end
