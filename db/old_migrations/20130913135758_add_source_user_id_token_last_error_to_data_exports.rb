class AddSourceUserIdTokenLastErrorToDataExports < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :data_exports,:atomic_switch => true do |m|
      m.add_column :source, "INT(12) DEFAULT 1"
      m.add_column :user_id, "bigint unsigned"
      m.add_column :token, "varchar(255)"
      m.add_column :last_error, "text"
      m.change_column :status, "INT(12)"
    end

    add_index :data_exports, [:account_id, :user_id, :source], 
                            :name => 'index_data_exports_on_account_id_user_id_and_source'
    add_index :data_exports, [:account_id, :source, :token], 
                            :name => 'index_data_exports_on_account_id_source_and_token'
  end

  def self.down
    remove_index :data_exports, :name => 'index_data_exports_on_account_id_source_and_token'
    remove_index :data_exports, :name => 'index_data_exports_on_account_id_user_id_and_source'
    Lhm.change_table :data_exports,:atomic_switch => true do |m|
      m.change_column :status, :boolean 
      m.remove_column  :last_error
      m.remove_column  :token
      m.remove_column  :user_id
      m.remove_column  :source
    end
  end
end