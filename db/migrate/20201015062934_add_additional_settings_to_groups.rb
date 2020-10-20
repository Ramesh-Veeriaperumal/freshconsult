class AddAdditionalSettingsToGroups < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :groups, atomic_switch: true do |m|
      m.add_column :additional_settings, :text
    end
  end

  def down
    Lhm.change_table :groups, atomic_switch: true do |m|
      m.remove_column :additional_settings
    end
  end
end
