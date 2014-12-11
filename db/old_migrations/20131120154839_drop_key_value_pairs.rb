class DropKeyValuePairs < ActiveRecord::Migration
	shard :none
	def self.up
		drop_table :key_value_pairs
	end

	def self.down
		create_table :key_value_pairs do |t|
			t.string :key
			t.text :value
			t.string :obj_type
			t.column :account_id, "bigint unsigned"
		end  
	end
end
