class AddIndexWidgets < ActiveRecord::Migration
  shard :all
  def up
  	Lhm.change_table :widgets, :atomic_switch => true do |m|
      m.add_index [:application_id]
    end
  end

  def down
  	Lhm.change_table :widgets, :atomic_switch => true do |m|
      m.remove_index [:application_id]
    end
  end
end
