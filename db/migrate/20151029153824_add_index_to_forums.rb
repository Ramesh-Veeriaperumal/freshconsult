class AddIndexToForums < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :forums, :atomic_switch => true do |t|
      t.add_index [:account_id, :forum_category_id, :position]
    end
  end

  def down
    Lhm.change_table :forums, :atomic_switch => true do |t|
      t.remove_index [:account_id, :forum_category_id, :position]
    end
  end
end
