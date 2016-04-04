class AddSourceToAdminDataImport < ActiveRecord::Migration
  shard :none
  def self.up
    add_column :admin_data_imports, :source, :integer
  end

  def self.down
    remove_column :admin_data_imports, :source
  end
end
