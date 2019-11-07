class AddPicklistIdToSectionPicklistMapping < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def self.up
    # TODO: drop picklist_value_id after deprecating
    Lhm.change_table :section_picklist_value_mappings, atomic_switch: true do |m|
      m.add_column :picklist_id, 'MEDIUMINT'
      m.add_index [:account_id, :picklist_id], "index_section_picklist_val_on_account_id_and_picklist_id"
    end
  end

  def self.down
    Lhm.change_table :section_picklist_value_mappings, atomic_switch: true do |m|
      m.remove_index [:account_id, :picklist_id], "index_section_picklist_val_on_account_id_and_picklist_id"
      m.remove_column :picklist_id
    end
  end
end