class RemoveColsAddIndexToFfcalls < ActiveRecord::Migration
 shard :all
 
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_column :customer_data
      m.remove_column :customer_number
      m.add_index [:account_id,:customer_id,:created_at], 'index_ff_calls_on_account_id_customer_id_created_at'
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_index [:account_id,:customer_id,:created_at], 'index_ff_calls_on_account_id_customer_id_created_at'
      m.add_column :customer_number, "varchar(50) DEFAULT NULL"
      m.add_column :customer_data, :text
    end
  end
end
