class AddIndexDayPassUsages < ActiveRecord::Migration
  shard :none
  def up
  	Lhm.change_table :day_pass_usages, :atomic_switch => true do |m|
      m.add_index [:account_id,:user_id], "index_day_pass_usages_on_account_id_and_user_id"
    end
  end

  def down
  	Lhm.change_table :day_pass_usages, :atomic_switch => true do |m|
      m.remove_index [:account_id,:user_id], "index_day_pass_usages_on_account_id_and_user_id"
    end
  end
end
