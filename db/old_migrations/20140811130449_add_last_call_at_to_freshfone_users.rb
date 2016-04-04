class AddLastCallAtToFreshfoneUsers < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :freshfone_users, :atomic_switch => true do |m|
      m.add_column :last_call_at, :datetime
      m.add_index [:account_id, :last_call_at], 'index_ff_users_account_last_call'
    end
  end

  def self.down
    Lhm.change_table :freshfone_users, :atomic_switch => true do |m|
      m.remove_index [:account_id, :last_call_at], 'index_ff_users_account_last_call'
      m.remove_column :last_call_at
    end
  end

end
