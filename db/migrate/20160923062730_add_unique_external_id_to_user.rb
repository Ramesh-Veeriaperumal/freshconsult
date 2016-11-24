class AddUniqueExternalIdToUser < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :users, :atomic_switch => true do |m|
      m.add_column :unique_external_id,  "varchar(255)"
      m.add_unique_index [:account_id, :unique_external_id]
    end
  end
  
  def down
    Lhm.change_table :users, :atomic_switch => true do |m|
      m.remove_index [:account_id, :unique_external_id]
      m.remove_column :unique_external_id
    end
  end
end
