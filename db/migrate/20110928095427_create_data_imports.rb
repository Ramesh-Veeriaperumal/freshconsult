class CreateDataImports < ActiveRecord::Migration
  def self.up
    create_table :data_imports do |t|
      t.string :import_type
      t.boolean :status
      t.integer :account_id, :limit => 8

      t.timestamps
    end
  end

  def self.down
    drop_table :data_imports
  end
end
