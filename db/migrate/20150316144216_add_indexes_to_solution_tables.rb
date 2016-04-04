class AddIndexesToSolutionTables < ActiveRecord::Migration
  
  shard :all

	def migrate(direction)
		self.send(direction)
	end

	def up
		Lhm.change_table :solution_articles, :atomic_switch => true do |m|
			m.add_index [:account_id, :parent_id, :language_id], "index_articles_on_account_id_parent_id_and_language"
		end

		Lhm.change_table :solution_folders, :atomic_switch => true do |m|
			m.add_index [:account_id, :parent_id, :language_id], "index_solution_folders_on_account_id_parent_id_and_language"
		end

		Lhm.change_table :solution_categories, :atomic_switch => true do |m|				
			m.add_index [:account_id, :parent_id, :language_id], "index_solution_categories_on_account_id_parent_id_and_language"
		end

		Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
			m.add_index [:portal_id, :solution_category_meta_id], "index_portal_solution_categories_on_portal_id_category_meta_id"
		end

		Lhm.change_table :solution_customer_folders, :atomic_switch => true do |m|
			m.add_index [:account_id, :folder_meta_id], "index_solution_customer_folders_on_account_id_folder_meta_id"
		end

		Lhm.change_table :mobihelp_app_solutions, :atomic_switch => true do |m|
			m.add_index [:account_id, :solution_category_meta_id], "index_app_solutions_on_account_id_solution_category_meta_id"
		end
	end

	def down
		Lhm.change_table :solution_articles, :atomic_switch => true do |m|
			m.remove_index [:account_id, :parent_id, :language_id], "index_articles_on_account_id_parent_id_and_language"
		end

		Lhm.change_table :solution_folders, :atomic_switch => true do |m|
			m.remove_index [:account_id, :parent_id, :language_id], "index_solution_folders_on_account_id_parent_id_and_language"
		end

		Lhm.change_table :solution_categories, :atomic_switch => true do |m|
			m.remove_index [:account_id, :parent_id, :language_id], "index_solution_categories_on_account_id_parent_id_and_language"
		end

		Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
			m.remove_index [:portal_id, :solution_category_meta_id], "index_portal_solution_categories_on_portal_id_category_meta_id"
		end

		Lhm.change_table :solution_customer_folders, :atomic_switch => true do |m|
			m.remove_index [:account_id, :folder_meta_id], "index_solution_customer_folders_on_account_id_folder_meta_id"
		end

		Lhm.change_table :mobihelp_app_solutions, :atomic_switch => true do |m|
			m.remove_index [:account_id, :solution_category_meta_id], "index_app_solutions_on_account_id_solution_category_meta_id"
		end
	end
end
