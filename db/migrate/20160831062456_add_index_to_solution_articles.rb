class AddIndexToSolutionArticles < ActiveRecord::Migration

	shard :all
	def self.up
		Lhm.change_table :solution_articles, :atomic_switch => true do |m|
			m.add_index [:account_id, :language_id, :hits],
				"index_solution_articles_on_account_id_language_id_hits"
		end
	end

	def self.down
		Lhm.change_table :solution_articles, :atomic_switch => true do |m|
			m.remove_index [:account_id, :language_id, :hits],
				"index_solution_articles_on_account_id_language_id_hits"
		end
	end
end
