class AddPicklistIdAndDeletedToHelpdeskPicklistValues < ActiveRecord::Migration
  shard :all
 
  def migrate(direction)
    self.send(direction)
  end
 
  def up
    Lhm.change_table :helpdesk_picklist_values, :atomic_switch => true do |m|
      m.add_column :picklist_id, 'mediumint(8) unsigned'
      m.add_column :deleted, 'tinyint(1) DEFAULT 0'
    end
  end
 
  def down
    Lhm.change_table :helpdesk_picklist_values, :atomic_switch => true do |m|
      m.remove_column :picklist_id
      m.remove_column :deleted
    end
  end
end
