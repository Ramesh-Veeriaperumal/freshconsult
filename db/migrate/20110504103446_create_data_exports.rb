class CreateDataExports < ActiveRecord::Migration
  def self.up
    create_table :data_exports do |t|
      t.integer :account_id
      t.boolean :status

      t.timestamps
    end
  end

  def self.down
    drop_table :data_exports
  end
end
