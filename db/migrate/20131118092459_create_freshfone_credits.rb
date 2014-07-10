class CreateFreshfoneCredits < ActiveRecord::Migration
	shard :none
	def self.up
		create_table :freshfone_credits do |t|
			t.column  :account_id, "bigint unsigned"
			t.decimal :available_credit, :precision => 10, :scale => 4, :default => 0.0
			t.boolean :auto_recharge, :default => false
			t.integer :recharge_quantity
			t.integer :auto_recharge_threshold, :default => 5
			t.decimal :last_purchased_credit, :precision => 6, :scale => 2, :default => 0.0  
			t.timestamps
		end
		add_index :freshfone_credits, [ :account_id ]
	end

	def self.down
		drop_table :freshfone_credits
	end
end