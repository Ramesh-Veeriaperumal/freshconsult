class AddColumnsToSolutionTables < ActiveRecord::Migration

	#The migrations in the following files must be performed as well
	# 1. db/migrate/20141231133258_article_indexes.rb
	# 2. db/migrate/20141231135232_add_index_to_solution_folders.rb

	shard :all

	def migrate(direction)
		self.send(direction)
	end

	def up
		Lhm.change_table :solution_articles, :atomic_switch => true do |m|
			m.remove_column :language if Rails.env != "production" and Solution::Article.column_names.include?("language")
			m.add_column :language_id, :integer
		end

		Lhm.change_table :solution_folders, :atomic_switch => true do |m|
			m.add_column :parent_id, "bigint(20)"
			m.add_column :language_id, :integer
		end

		Lhm.change_table :solution_categories, :atomic_switch => true do |m|
			m.add_column :parent_id, "bigint(20)"
			m.add_column :language_id, :integer
		end

		Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
			m.add_column :solution_category_meta_id, "bigint(20)"
		end

		Lhm.change_table :solution_customer_folders, :atomic_switch => true do |m|
			m.add_column :folder_meta_id, "bigint(20)"
		end

		Lhm.change_table :mobihelp_app_solutions, :atomic_switch => true do |m|
			m.add_column :solution_category_meta_id, "bigint(20)"
		end
	end

	def down
		Lhm.change_table :solution_articles, :atomic_switch => true do |m|
			m.remove_column :language_id
		end

		Lhm.change_table :solution_folders, :atomic_switch => true do |m|
			m.remove_column :parent_id
			m.remove_column :language_id
		end

		Lhm.change_table :solution_categories, :atomic_switch => true do |m|
			m.remove_column :parent_id
			m.remove_column :language_id
		end

		Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
			m.remove_column :solution_category_meta_id
		end

		Lhm.change_table :solution_customer_folders, :atomic_switch => true do |m|
			m.remove_column :folder_meta_id
		end

		Lhm.change_table :mobihelp_app_solutions, :atomic_switch => true do |m|
			m.remove_column :solution_category_meta_id
		end
	end
end
