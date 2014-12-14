class CleanUpIndexFreshfoneCalls < ActiveRecord::Migration
  shard :all
  
  def self.up
     Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_index [:account_id, :notable_type, :notable_id], 'index_ff_calls_on_account_id_notable_type_id'
      m.remove_index ["account_id","customer_number(16)"], 'index_freshfone_calls_on_account_id_and_customer_number'
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_index ["account_id", "customer_number(16)"], 'index_freshfone_calls_on_account_id_and_customer_number'
      m.remove_index [:account_id, :notable_type, :notable_id], 'index_ff_calls_on_account_id_notable_type_id'
    end
  end
end
