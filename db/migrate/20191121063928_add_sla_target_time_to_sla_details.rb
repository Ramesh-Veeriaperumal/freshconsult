class AddSlaTargetTimeToSlaDetails < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :sla_details, atomic_switch: true do |m|
      m.add_column :sla_target_time, :text
    end
  end

  def down
    Lhm.change_table :sla_details, atomic_switch: true do |m|
      m.remove_column :sla_target_time
    end
  end
end
