class AddReputationToAccounts < ActiveRecord::Migration

  shard :all
  
  def self.up
    Lhm.change_table :accounts, :atomic_switch => true do |m|
      m.add_column :reputation, "tinyint DEFAULT 0"
      m.add_index [:reputation]
    end
  end

  def self.down
     Lhm.change_table :accounts, :atomic_switch => true do |m|
        m.remove_index [:reputation]
        m.remove_column :reputation
    end
  end
end
