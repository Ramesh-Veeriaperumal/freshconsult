class AddUserIdColumnToDataImports < ActiveRecord::Migration
  shard :all

  def self.up
    add_column :admin_data_imports, :user_id, "bigint(20) DEFAULT NULL"
  end

  def self.down
    remove_column :admin_data_imports, :user_id
  end
end
