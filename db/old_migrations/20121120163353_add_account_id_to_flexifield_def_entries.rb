class AddAccountIdToFlexifieldDefEntries < ActiveRecord::Migration
  def self.up
    add_column :flexifield_def_entries, :account_id, "bigint unsigned"
  end

  def self.down
    remove_column :flexifield_def_entries, :account_id
  end
end
