class CreateFreshfoneNumbers < ActiveRecord::Migration
	shard :none
	def self.up
		create_table :freshfone_numbers do |t|
			t.column  :account_id, "bigint unsigned"
			t.string  :number, :limit => 50
			t.string  :display_number, :limit => 50
			t.string  :region, :default => "", :limit => 100
			t.string  :country, :default => "", :limit => 20
			t.decimal :rate, :precision => 6, :scale => 2
			t.boolean :record, :default => true
			t.integer :queue_wait_time, :default => 2
			t.integer :max_queue_length, :default => 3
			t.integer :state, :limit => 1, :default => 1
			t.string  :number_sid
			t.integer :number_type
			t.integer :state, :limit => 1, :default => 1
			t.integer :voice, :default => 0
			t.boolean :deleted, :default => false
			t.text    :on_hold_message
			t.text    :non_availability_message
			t.text    :voicemail_message
			t.integer :business_calendar_id, :limit => 8
			t.datetime :next_renewal_at

			t.timestamps
		end
		add_index :freshfone_numbers, [ :account_id, :number ]
		add_index :freshfone_numbers, [ :state, :next_renewal_at ]
	end

	def self.down
		drop_table :freshfone_numbers
	end
end