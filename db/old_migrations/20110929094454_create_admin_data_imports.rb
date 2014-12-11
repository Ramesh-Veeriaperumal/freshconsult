class CreateAdminDataImports < ActiveRecord::Migration
  def self.up
    create_table :admin_data_imports do |t|
      t.string  :import_type
      t.boolean :status
      t.integer :account_id, :limit => 8

      t.timestamps
    end
    add_index :admin_data_imports, [:account_id, :created_at], :name => 'index_data_imports_on_account_id_and_created_at'
  end

  def self.down
    drop_table :admin_data_imports
  end
end
