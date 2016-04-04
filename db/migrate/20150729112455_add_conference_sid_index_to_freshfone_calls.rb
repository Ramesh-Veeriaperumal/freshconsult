class AddConferenceSidIndexToFreshfoneCalls < ActiveRecord::Migration
  shard :all

  def up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_index [:account_id, :conference_sid]
    end
  end

  def down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_index [:account_id, :conference_sid]
    end
  end
end
