class UpdateIndexesFreshfoneCallsMeta < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :freshfone_calls_meta, :atomic_switch => true do |m|
      m.remove_index [:account_id, :call_id], 'index_ff_meta_data_on_account_id_and_call_id'
      m.remove_index [:account_id, :group_id], 'index_ff_meta_data_on_account_id_and_group_id'
      m.add_index [:account_id, :call_id, :group_id], 'index_ff_calls_on_account_id_call_id_group_id'
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls_meta, :atomic_switch => true do |m|
      m.remove_index  [:account_id, :call_id, :group_id], 'index_ff_calls_on_account_id_call_id_group_id'
      m.add_index [:account_id, :group_id], 'index_ff_meta_data_on_account_id_and_group_id'
      m.add_index [:account_id, :call_id], 'index_ff_meta_data_on_account_id_and_call_id'
    end
  end
end
