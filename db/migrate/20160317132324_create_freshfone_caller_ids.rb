class CreateFreshfoneCallerIds < ActiveRecord::Migration
  shard :none
  def up
    create_table :freshfone_caller_ids do |t|
       t.integer :account_id , :limit => 8, :null => false
       t.string :name, :limit => 20, :null => true
       t.string :number_sid, :limit => 50, :null => false
       t.string :number, :limit => 20, :null => false
       t.timestamps
    end
    add_index :freshfone_caller_ids, [:account_id]
  end

  def down
    drop_table :freshfone_caller_ids
  end

end
