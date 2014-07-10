class CreateFreshfonePayments < ActiveRecord::Migration
	shard :none
	def self.up
		create_table :freshfone_payments do |t|
			t.column :account_id, "bigint unsigned"
			t.decimal :purchased_credit, :precision => 10, :scale => 4, :default => 0.0
			t.boolean :status
			t.string :status_message
			t.timestamps
		end
		add_index :freshfone_payments, [ :account_id ]
	end

	def self.down
		drop_table :freshfone_payments
	end
end
