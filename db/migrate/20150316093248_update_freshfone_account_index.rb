class UpdateFreshfoneAccountIndex < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.remove_index [:account_id]
      m.add_unique_index [:account_id], 'index_freshfone_accounts_on_account_id'
    end
  end

  def self.down
    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.remove_index [:account_id]
      m.add_index [:account_id], 'index_freshfone_accounts_on_account_id'
    end
  end
end
