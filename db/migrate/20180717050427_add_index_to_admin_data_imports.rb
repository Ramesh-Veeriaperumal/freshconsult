class AddIndexToAdminDataImports < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def self.up
    add_index :admin_data_imports, [:account_id, :source, :status],
              name: 'index_data_exports_on_account_id_source_and_status'
  end

  def self.down
    remove_index :admin_data_imports, name: 'index_data_exports_on_account_id_source_and_status'
  end
end
