class AddIndexOnNameAndAccountIdToUsers < ActiveRecord::Migration
	shard :none
  def self.up
  	Lhm.change_table :users, :atomic_switch => true do |m|
      m.add_index [:account_id, :name]
  	end
  end

  def self.down
  	Lhm.change_table :users, :atomic_switch => true do |m|
      m.remove_index [:account_id, name]
  	end
  end
end
