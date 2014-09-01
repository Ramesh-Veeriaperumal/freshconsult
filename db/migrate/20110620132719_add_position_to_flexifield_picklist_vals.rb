class AddPositionToFlexifieldPicklistVals < ActiveRecord::Migration
  def self.up
    add_column :flexifield_picklist_vals, :position, :integer
  end

  def self.down
    remove_column :flexifield_picklist_vals, :position
  end
end
