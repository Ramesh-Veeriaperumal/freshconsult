class CreateHelpdeskPicklistValues < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_picklist_values do |t|
      t.integer :pickable_id,        :limit => 8
      t.string :pickable_type
      t.integer :position
      t.string :value

      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_picklist_values
  end
end
