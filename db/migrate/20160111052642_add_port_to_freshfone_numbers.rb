class AddPortToFreshfoneNumbers < ActiveRecord::Migration
shard :all

  def up
  	Lhm.change_table :freshfone_numbers, :atomic_switch => true do |t|
      t.add_column :port, "TINYINT(4)"
    end
  end

  def down
  	Lhm.change_table :freshfone_numbers, :atomic_switch => true do |t|
      t.remove_column :port
   	end
  end
end
