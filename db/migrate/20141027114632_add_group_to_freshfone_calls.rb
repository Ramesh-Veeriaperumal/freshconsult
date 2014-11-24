class AddGroupToFreshfoneCalls < ActiveRecord::Migration
  shard :all
  
  def self.up
    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.add_column :group_id, "int(11) DEFAULT NULL" 
    end

    execute("update freshfone_calls, freshfone_calls_meta set freshfone_calls.group_id = freshfone_calls_meta.group_id 
      where freshfone_calls.id = freshfone_calls_meta.call_id")
  end

  def self.down    
    execute("INSERT INTO freshfone_calls_meta (account_id, call_id, group_id, created_at, updated_at) 
     SELECT account_id, id, group_id, created_at, updated_at FROM freshfone_calls 
     ON DUPLICATE key update freshfone_calls_meta.group_id = freshfone_calls.group_id")

    Lhm.change_table :freshfone_calls, :atomic_switch => true do |m|
      m.remove_column :group_id
    end
  end
end
