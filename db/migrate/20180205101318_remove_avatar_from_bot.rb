class RemoveAvatarFromBot < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end
  
  def up
    Lhm.change_table :bots, :atomic_switch => true do |m|
      m.remove_column :avatar
    end
  end

  def down
    Lhm.change_table :bots, :atomic_switch => true do |m|
      m.add_column :avatar, :text
    end
  end
end
