class CreateFreshfoneIvrs < ActiveRecord::Migration
	shard :none
	def self.up
		create_table :freshfone_ivrs do |t|
			t.integer  :account_id, :limit => 8, :null => false
			t.column   :freshfone_number_id, "bigint unsigned", :null => false
			t.text     :ivr_data
			t.text     :ivr_draft_data
			t.boolean  :active, :default => 1

			t.timestamps
		end
		add_index :freshfone_ivrs, [ :account_id, :freshfone_number_id ]
	end

	def self.down
		drop_table :freshfone_ivrs
	end
end
