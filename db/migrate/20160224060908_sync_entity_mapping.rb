class SyncEntityMapping < ActiveRecord::Migration

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :sync_entity_mappings do |t|
      t.column :user_id, "bigint unsigned"
      t.string :entity_id
      t.column :sync_account_id, "bigint unsigned"
      t.column :account_id, "bigint unsigned"
      t.timestamps
    end
    add_index :sync_entity_mappings, [:sync_account_id, :account_id, :user_id], :unique => true, :name => "index_on_sync_account_id_account_id_user_id"
    add_index :sync_entity_mappings, [:sync_account_id, :account_id, :entity_id], :unique => true, :name => "index_on_sync_account_id_account_id_entity_id"
  end

  def down
    drop_table :sync_entity_mappings
  end
end
