class CreateGroupTypes < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    send(direction)
  end
  
  def up
    create_table :group_types do |t|
      t.integer :group_type_id
      t.string  :name
      t.boolean :deleted, :default => false
      t.string	:label
      t.integer :account_id, :null => false, :limit => 8 
      t.boolean :default, :default => false
      
      t.timestamps
    end
    add_index :group_types, [:account_id, :group_type_id], :name => 'index_account_id_group_type_id_on_group_types', :unique => true
    add_index :group_types, [:account_id, :name], :name => 'index_account_id_name_on_group_types', :unique => true
  end

  def down
    drop_table :group_types
  end
end
