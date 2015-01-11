class ArticleIndexes < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :solution_articles, :atomic_switch => true do |m|
      # Columns for Dynamic Solutions
      m.add_column :language, "int(12)"
      m.add_column :parent_id, "bigint(20)"
      m.add_column :outdated, "tinyint(1) DEFAULT '0'"
      m.add_index ["account_id", "parent_id", "language"]
      
      # Modifying Author
      m.add_column :modified_by, "bigint(20)"
      
      # Additional Columns
      m.add_column :int_01, "bigint(20)"
      m.add_column :int_02, "bigint(20)"
      m.add_column :int_03, "bigint(20)"
      m.add_column :bool_01, "tinyint(1)"
      m.add_column :datetime_01, "datetime"
      m.add_column :string_01, "varchar(255)"
      m.add_column :string_02, "varchar(255)"
      
      m.remove_index "account_id" #Index Name is 'index_solution_articles_on_account_id'
      
      m.add_index ["account_id", "folder_id", "position"]
      m.add_index ["account_id", "folder_id", "title(10)"]
      m.add_index ["account_id", "folder_id", "created_at"], "index_solution_articles_on_acc_folder_created_at"
    end
  end

  def self.down
    Lhm.change_table :solution_articles, :atomic_switch => true do |m|
      # Columns for Dynamic Solutions
      m.remove_index ["account_id", "parent_id", "language"]
      m.remove_column :language
      m.remove_column :parent_id
      m.remove_column :outdated
      
      m.remove_column :modified_by
      
      # Additional Columns
      m.remove_column :int_01
      m.remove_column :int_02
      m.remove_column :int_03
      m.remove_column :bool_01
      m.remove_column :datetime_01
      m.remove_column :string_01
      m.remove_column :string_02
      
      m.add_index ["account_id", "folder_id"], "index_solution_articles_on_account_id"
      
      m.remove_index ["account_id", "folder_id", "position"]
      m.remove_index ["account_id", "folder_id", "title(10)"]
      m.remove_index "acc_folder_created_at"
      
    end
  end
end
