class CreateFreshfoneUsers < ActiveRecord::Migration
	shard :none
	def self.up
		create_table :freshfone_users do |t|
			t.column  :account_id, "bigint unsigned", :null => false
			t.column  :user_id, "bigint unsigned", :null => false
			t.integer :presence, :default => 0
			t.integer :incoming_preference, :default => 0
			t.boolean :available_on_phone, :default => false

			t.timestamps
		end
		add_index :freshfone_users, [ :account_id, :user_id ], :unique => true
		add_index :freshfone_users, [ :account_id, :presence ]
	end

	def self.down
		drop_table :freshfone_users
	end
end
