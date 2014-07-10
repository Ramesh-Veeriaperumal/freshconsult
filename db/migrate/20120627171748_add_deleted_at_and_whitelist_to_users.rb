class AddDeletedAtAndWhitelistToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :deleted_at, :datetime
    add_column :users, :whitelisted, :boolean, :default => false
  end

  def self.down
    remove_column :users, :whitelisted
    remove_column :users, :deleted_at
  end
end
