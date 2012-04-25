class AddAccountIdToFlexifields < ActiveRecord::Migration
  def self.up
    add_column :flexifields, :account_id,  "bigint unsigned"
  end

  def self.down
    remove_column :flexifields, :account_id
  end
end
