class AddParentIdIndexToSolutionCategories < ActiveRecord::Migration
	shard :all

	def migrate(direction)
		self.send(direction)
	end

	def up
		Lhm.change_table :solution_categories, :atomic_switch => true do |m|				
			m.add_index [:account_id, :parent_id, :position], "index_solution_categories_on_account_id_parent_id_and_position"
		end
	end

	def down
		Lhm.change_table :solution_categories, :atomic_switch => true do |m|
			m.remove_index [:account_id, :parent_id, :position], "index_solution_categories_on_account_id_parent_id_and_position"
		end
	end
end
