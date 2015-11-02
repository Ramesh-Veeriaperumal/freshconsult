class AddAbandonStateToFreshfoneCalls < ActiveRecord::Migration
shard :none
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_column :abandon_state, "BIGINT(20) UNSIGNED DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      remove_column :abandon_state
    end
  end
end
