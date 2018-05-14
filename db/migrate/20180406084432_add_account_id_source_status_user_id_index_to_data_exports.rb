class AddAccountIdSourceStatusUserIdIndexToDataExports < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    add_index :data_exports, [:account_id, :source, :status, :user_id], :name => 'index_data_exports_on_account_id_source_status_and_user_id'
  end

  def down
    remove_index :data_exports, :name => 'index_data_exports_on_account_id_source_status_and_user_id'
  end
end
