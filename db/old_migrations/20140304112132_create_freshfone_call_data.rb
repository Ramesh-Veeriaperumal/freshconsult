class CreateFreshfoneCallData < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :freshfone_calls_meta do |t|
      t.column  :account_id, "bigint unsigned"
      t.column  :call_id, "bigint unsigned"
      t.integer :group_id, "bigint unsigned"
      
      t.timestamps
    end
    add_index(:freshfone_calls_meta, [:account_id, :call_id],
     :name => "index_ff_meta_data_on_account_id_and_call_id")
    add_index(:freshfone_calls_meta, [:account_id, :group_id],
     :name => "index_ff_meta_data_on_account_id_and_group_id")
  end

  def self.down
    drop_table :freshfone_calls_meta
  end
end
