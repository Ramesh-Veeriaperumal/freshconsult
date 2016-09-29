class AddAcwTimeoutToFreshfoneAccounts < ActiveRecord::Migration
  shard :all

  def self.up

    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.add_column :acw_timeout, "integer(11) DEFAULT 1"
    end

  end

  def self.down

    Lhm.change_table :freshfone_accounts, :atomic_switch => true do |m|
      m.remove_column :acw_timeout
    end

  end
end
