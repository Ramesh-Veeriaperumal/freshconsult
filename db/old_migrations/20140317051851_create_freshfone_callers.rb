class CreateFreshfoneCallers < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :freshfone_callers do |t|
      t.column :account_id, "bigint unsigned"
      t.string :number, :limit => 50
      t.string :country
      t.string :state
      t.string :city

      t.timestamps
    end
    
    add_index(:freshfone_callers, [:account_id, :number], 
      :name => "index_ff_callers_on_account_id_and_number")
  end

  def self.down
    drop_table :freshfone_callers
  end
end
