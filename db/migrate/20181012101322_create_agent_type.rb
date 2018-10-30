class CreateAgentType < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end
  def up
    create_table :agent_types do |t|
      t.integer :agent_type_id
      t.string  :name
      t.string :label
      t.boolean :default, :default => false
      t.column  :account_id, "bigint unsigned", :null => false 
      t.integer :deleted, :default => false
      t.timestamps
  	end
    add_index :agent_types, [:account_id, :name], :name => 'index_account_id_and_name_on_agent_types', :unique => true
    add_index :agent_types, [:account_id, :agent_type_id], :name => 'index_account_id_and_type_id__on_agent_types'

  end	

  def down
    drop_table :agent_types
  end
end

