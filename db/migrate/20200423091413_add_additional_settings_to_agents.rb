class AddAdditionalSettingsToAgents < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :agents, atomic_switch: true do |a|
      a.add_column :additional_settings, :text
    end
  end

  def down
    Lhm.change_table :agents do |a|
      a.remove_column :additional_settings
    end
  end
end
