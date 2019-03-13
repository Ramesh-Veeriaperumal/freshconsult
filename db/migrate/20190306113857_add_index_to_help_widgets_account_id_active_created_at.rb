class AddIndexToHelpWidgets < ActiveRecord::Migration
  shard(:all)

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :help_widgets, atomic_switch: true do |m|
      m.remove_index [:account_id, :active]
      m.add_index [:account_id, :active, :created_at]
    end
  end

  def down
    Lhm.change_table :help_widgets, atomic_switch: true do |m|
      m.add_index [:account_id, :active]
      m.remove_index [:account_id, :active, :created_at]
    end
  end
end
