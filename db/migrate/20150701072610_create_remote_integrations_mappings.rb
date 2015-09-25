class CreateRemoteIntegrationsMappings < ActiveRecord::Migration
	shard :none

  def migrate(direction)
    self.send(direction)
  end
  
  def up
  	create_table :remote_integrations_mappings do |t|
      t.string :remote_id
      t.string :type
      t.integer :account_id, :limit => 8
      t.text :configs
      t.timestamps
  	end
    add_index :remote_integrations_mappings, [:remote_id, :type], :unique => true, :name => "index_remote_integrations_mappings_on_remote_id_and_type"
  end

  def down
  	drop_table :remote_integrations_mappings
  end
end
