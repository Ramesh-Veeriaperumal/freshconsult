class RemoveIndexFromFreshfoneCalls < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_index [:account_id, :freshfone_number_id]
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_index [:account_id, :freshfone_number_id], 'index_freshfone_calls_on_account_id_and_freshfone_number_id'
    end
  end
end
