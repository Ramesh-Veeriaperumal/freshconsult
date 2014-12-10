class AddFolderTypeColumnToCaFolders < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :ca_folders, :atomic_switch => true do |m|
      m.add_column :folder_type, :integer
      m.add_column :deleted, "tinyint(1) DEFAULT false"
      m.remove_index [:account_id]
      m.add_index ["account_id", "folder_type"], "index_ca_folders_on_account_id_folder_type"
    end
  end

  def self.down
    Lhm.change_table :ca_folders, :atomic_switch => true do |m|
      m.add_index ["account_id"], 'Index_ca_folders_on_account_id'
      m.remove_column :folder_type
      m.remove_column :deleted
      m.remove_index ["account_id", "folder_type"]
    end
  end

end
