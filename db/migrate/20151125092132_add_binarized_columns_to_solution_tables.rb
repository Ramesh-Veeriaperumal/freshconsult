class AddBinarizedColumnsToSolutionTables < ActiveRecord::Migration

	shard :all

	def self.up
		Lhm.change_table :solution_article_meta, :atomic_switch => true do |m|
			m.add_column :available, "varchar(255)"
			m.add_column :draft, "varchar(255)"
			m.add_column :published, "varchar(255)"
			m.add_column :outdated, "varchar(255)"
		end

		Lhm.change_table :solution_folder_meta, :atomic_switch => true do |m|
			m.add_column :available, "varchar(255)"
		end

		Lhm.change_table :solution_category_meta, :atomic_switch => true do |m|
			m.add_column :available, "varchar(255)"
		end
	end


	def self.down
		Lhm.change_table :solution_category_meta, :atomic_switch => true do |m|
			m.remove_column :available
		end

		Lhm.change_table :solution_folder_meta, :atomic_switch => true do |m|
			m.remove_column :available
		end

		Lhm.change_table :solution_article_meta, :atomic_switch => true do |m|
			m.remove_column :outdated
			m.remove_column :published
			m.remove_column :draft
			m.remove_column :available
		end
	end


end
