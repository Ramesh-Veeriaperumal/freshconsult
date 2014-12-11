class AddImportIdToFlexifieldDefEntries < ActiveRecord::Migration
  def self.up
    add_column :flexifield_def_entries, :import_id, :integer
  end

  def self.down
    remove_column :flexifield_def_entries, :import_id
  end
end
