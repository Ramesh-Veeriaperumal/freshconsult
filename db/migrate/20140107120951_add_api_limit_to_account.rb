class AddApiLimitToAccount < ActiveRecord::Migration
	shard :all
  def self.up
  	Lhm.change_table :account_additional_settings,:atomic_switch => true do |m|
      m.add_column :api_limit, "INT(12) DEFAULT 1000"
    end
  end

  def self.down
  	Lhm.change_table :account_additional_settings,:atomic_switch => true do |m|
      m.remove_column :api_limit
    end
  end
end
