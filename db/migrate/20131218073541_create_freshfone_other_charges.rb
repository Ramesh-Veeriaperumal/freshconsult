class CreateFreshfoneOtherCharges < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :freshfone_other_charges do |t|
    	t.column  :account_id, "bigint unsigned"
			t.integer :action_type
			t.column  :freshfone_number_id, "bigint unsigned"
			t.float   :debit_payment

      t.timestamps
    end
    add_index :freshfone_other_charges, [ :account_id ]
  end

  def self.down
    drop_table :freshfone_other_charges
  end
end
