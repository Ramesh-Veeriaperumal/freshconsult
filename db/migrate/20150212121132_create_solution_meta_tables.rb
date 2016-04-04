class CreateSolutionMetaTables < ActiveRecord::Migration

	shard :all

	def migrate(direction)
		self.send(direction)
	end

	def up
		create_table :solution_article_meta do |t|
			t.integer  "position"
			t.integer  "art_type"
			t.integer  "thumbs_up",    :default => 0
			t.integer  "thumbs_down",  :default => 0
			t.integer  "hits", 	:default => 0
			t.integer  "solution_folder_meta_id",    :limit => 8
			t.integer  "account_id",   :limit => 8, :null => false
			t.timestamps
		end

		add_index :solution_article_meta, [:account_id, :solution_folder_meta_id, :created_at], 
			:name => 'index_article_meta_on_account_id_folder_meta_and_created_at'
		add_index :solution_article_meta, [:account_id, :solution_folder_meta_id, :position], 
			:name => 'index_article_meta_on_account_id_folder_meta_and_position'

		create_table :solution_folder_meta do |t|
			t.integer  "visibility",  :limit => 8
			t.integer  "position"
			t.boolean  "is_default",  :default => false
			t.integer  "solution_category_meta_id", :limit => 8
			t.integer  "account_id",  :limit => 8, :null => false
			t.timestamps
		end

		add_index :solution_folder_meta, [:account_id, :solution_category_meta_id, :position], 
			:name => 'index_folder_meta_on_account_id_category_meta_and_position'

		create_table :solution_category_meta do |t|
			t.integer  "position"
			t.boolean  "is_default",  :default => false
			t.integer  "account_id",  :limit => 8
			t.timestamps
		end

		add_index :solution_category_meta, [:account_id], :name => 'index_solution_category_meta_on_account_id'
	end
	
	def down
		drop_table :solution_article_meta
		drop_table :solution_folder_meta
		drop_table :solution_category_meta
	end
end
