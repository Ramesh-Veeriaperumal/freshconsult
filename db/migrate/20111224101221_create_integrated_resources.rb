class CreateIntegratedResources < ActiveRecord::Migration
  def self.up
    create_table :integrated_resources do |t|
      t.column :installed_application_id, "bigint unsigned"
      t.string :remote_integratable_id
      t.column :local_integratable_id, "bigint unsigned"
      t.string :local_integratable_type
      t.column :account_id, "bigint unsigned"
    end
  end

  def self.down
    drop_table :integrated_resources
  end
end
