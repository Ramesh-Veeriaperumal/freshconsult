class AddColumnsToDataImports < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :admin_data_imports, :atomic_switch => true do |m|
      m.add_column :import_status, "int(11) DEFAULT '1'"
      m.add_column :last_error, "text DEFAULT NULL"
    end
  end

  def down
    Lhm.change_table :admin_data_imports, :atomic_switch => true do |m|
      m.remove_column :import_status
      m.remove_column :last_error
    end
  end
end