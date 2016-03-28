class AddCallerIdToFreshfoneNumbers < ActiveRecord::Migration
  shard :none

  def up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |t|
      t.add_column :caller_id, "integer(8)"
    end
  end

  def down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |t|
      t.remove_column :caller_id
    end
  end

end
