class AddDetailsToFlexifieldDefs < ActiveRecord::Migration
  shard :all
  def self.up
  	Lhm.change_table :flexifield_defs, :atomic_switch => true do |m|
  		m.add_column :product_id, "bigint(20) DEFAULT NULL"
  		m.add_column :active,"tinyint(1) DEFAULT '1'"
  	end
  end

  def self.down
  	Lhm.change_table :flexifield_defs, :atomic_switch => true do |m|
  		m.remove_column :product_id
  		m.remove_column :active
  	end
  end
end