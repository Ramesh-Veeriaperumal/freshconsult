class AddAutosuggestSolutionsFeature < ActiveRecord::Migration
	def self.up
		execute <<-SQL
	      INSERT INTO features 
	        (account_id, type, created_at, updated_at) 
	        SELECT id, 'AutoSuggestSolutionsFeature', created_at, created_at FROM accounts
	    SQL
	end

	def self.down
		execute <<-SQL
	      DELETE FROM features WHERE type = 'AutoSuggestSolutionsFeature'
	    SQL
	end
end
