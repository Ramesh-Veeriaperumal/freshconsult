class ChangeDefaultValueOfEnableInPortalInBots < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end
  
  def up
    Lhm.change_table :bots, atomic_switch: true do |m|
      m.change_column :enable_in_portal, 'tinyint(1) DEFAULT 0'
    end
  end

  def down
    Lhm.change_table :bots, atomic_switch: true do |m|
      m.change_column :enable_in_portal, 'tinyint(1) DEFAULT 0'
    end
  end
end
