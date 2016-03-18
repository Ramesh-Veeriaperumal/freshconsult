class AddStateIndexToFreshfoneAccounts < ActiveRecord::Migration
  shard :all

  def up
    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.add_index [:state], "index_freshfone_accounts_on_state"
    end
  end

  def down
    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.remove_index [:state], "index_freshfone_accounts_on_state"
    end
  end
end
