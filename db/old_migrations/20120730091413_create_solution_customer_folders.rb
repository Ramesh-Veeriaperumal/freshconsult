class CreateSolutionCustomerFolders < ActiveRecord::Migration
  def self.up
    create_table :solution_customer_folders do |t|
      t.column :customer_id , "bigint unsigned"
      t.column :folder_id , "bigint unsigned"
      t.column :account_id ,"bigint unsigned"

      t.timestamps
    end
    add_index :solution_customer_folders, [:account_id, :customer_id], :name => 'index_customer_folder_on_account_id_and_customer_id'
    add_index :solution_customer_folders, [:account_id, :folder_id], :name => 'index_customer_folder_on_account_id_and_folder_id'

  end

  def self.down
    drop_table :solution_customer_folders
  end
end
