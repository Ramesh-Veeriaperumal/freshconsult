class CreateFreshfoneAccounts < ActiveRecord::Migration
	shard :none
	def self.up
		create_table :freshfone_accounts do |t|
			t.column   :account_id, "bigint unsigned"
			t.string   :friendly_name
			t.string   :twilio_subaccount_id
			t.string   :twilio_subaccount_token
			t.string   :twilio_application_id
			t.integer  :state, :limit => 1, :default => 1
			t.boolean  :deleted, :default => false
			t.string   :queue
			t.datetime :expires_on

			t.timestamps
		end
		add_index :freshfone_accounts, [ :account_id ]
		add_index :freshfone_accounts, [ :account_id, :state, :expires_on ]
	end

	def self.down
		drop_table :freshfone_accounts
	end
end