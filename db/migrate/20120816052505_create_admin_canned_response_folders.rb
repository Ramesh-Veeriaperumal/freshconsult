class CreateAdminCannedResponseFolders < ActiveRecord::Migration
  def self.up
    create_table :ca_folders do |t|
    	t.string :name
    	t.boolean :is_default, :default => false
    	t.column :account_id, "bigint unsigned"
      t.timestamps
    end
  end

  def self.down
    drop_table :ca_folders
  end
end
