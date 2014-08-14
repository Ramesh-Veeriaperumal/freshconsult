class PortalSolutionCategoriesIndex < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
        m.add_index [:portal_id, :solution_category_id], 'index_on_portal_and_soln_categ_id'
    end
  end

  def self.down
    Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
        m.remove_index [:portal_id, :solution_category_id], 'index_on_portal_and_soln_categ_id'
    end
  end
end
