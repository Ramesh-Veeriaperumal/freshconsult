class AddCreatedIndexToFresfoneCalls < ActiveRecord::Migration
  shard :none
  
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_index [:account_id,:created_at], "index_freshfone_calls_on_account_id_and_created_at"
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
        m.remove_index [:account_id,:created_at], "index_freshfone_calls_on_account_id_and_created_at"
    end
  end
end
