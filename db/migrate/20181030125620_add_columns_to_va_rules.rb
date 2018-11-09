class AddColumnsToVaRules < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :va_rules, :atomic_switch => true do |m|
      m.add_column :condition_data, :text
      m.add_column :outdated, 'tinyint(1) DEFAULT 0'
      m.add_column :last_updated_by, 'bigint(20) DEFAULT NULL'
    end
  end

  def down
    Lhm.change_table :va_rules, :atomic_switch => true do |m|
      m.remove_column :condition_data
      m.remove_column :outdated
      m.remove_column :last_updated_by
    end
  end
end
