class AddIndexToPortalSolutionCategories < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :portal_solution_categories, atomic_switch: true do |portal_solution_category|
      portal_solution_category.add_index [:account_id, :portal_id, :solution_category_meta_id], 'index_psc_on_acc_id_and_portal_id_and_sol_cat_meta_id'
    end
  end

  def down
    Lhm.change_table :portal_solution_categories, atomic_switch: true do |portal_solution_category|
      portal_solution_category.remove_index [:account_id, :portal_id, :solution_category_meta_id], 'index_psc_on_acc_id_and_portal_id_and_sol_cat_meta_id'
    end
  end
end
