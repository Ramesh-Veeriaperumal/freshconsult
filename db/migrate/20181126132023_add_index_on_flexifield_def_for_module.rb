class AddIndexOnFlexifieldDefForModule < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :flexifield_defs, :atomic_switch => true do |m|
      m.add_index [:account_id, :module], 'index_flexifield_defs_on_module'
    end
  end

  def down
    Lhm.change_table :flexifield_defs, :atomic_switch => true do |m|
      m.remove_index [:account_id, :module], 'index_flexifield_defs_on_module'
    end
  end
end
