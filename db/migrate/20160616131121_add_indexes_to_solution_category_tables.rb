class AddIndexesToSolutionCategoryTables < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def self.up
    Lhm.change_table :solution_category_meta, :atomic_switch => true do |m|
      m.add_index [:account_id, :position], "index_category_meta_on_account_id_position"
    end

    Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
      m.add_index [:account_id, :solution_category_meta_id], "portal_solution_categories_on_account_id_category_meta_id"
    end
  end

  def self.down
  	Lhm.change_table :solution_category_meta, :atomic_switch => true do |m|
      m.remove_index([:account_id, :position], "index_category_meta_on_account_id_position")
    end

    Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
    	m.remove_index([:account_id, :solution_category_meta_id],"portal_solution_categories_on_account_id_category_meta_id")
    end
  end
end
