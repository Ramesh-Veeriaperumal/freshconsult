class RemoveSolutionsUniqueIndexes < ActiveRecord::Migration
  
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :solution_categories, :atomic_switch => true do |m|
      m.remove_index "account_id_and_name"
      m.ddl("ALTER TABLE %s 
                ADD UNIQUE INDEX index_solution_categories_on_account_id_language_id_and_name 
                (`account_id`, `language_id`, `name`)" % m.name)
    end
    
    Lhm.change_table :solution_folders, :atomic_switch => true do |m|
      m.remove_index "category_id_and_name"
    end
  end

  def down
    Lhm.change_table :solution_categories, :atomic_switch => true do |m|
      m.remove_index "account_id_language_id_and_name"
      m.ddl("ALTER TABLE %s 
                ADD UNIQUE INDEX index_solution_categories_on_account_id_and_name 
                (`account_id`, `name`)" % m.name)
    end
    
    Lhm.change_table :solution_folders, :atomic_switch => true do |m|
      m.ddl("ALTER TABLE %s 
                ADD UNIQUE INDEX index_solution_folders_on_category_id_and_name 
                (`category_id`, `name`)" % m.name)
    end
  end
end
