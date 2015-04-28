class CreateSolutionArticleBody < ActiveRecord::Migration
	shard :all

	def migrate(direction)
		self.send(direction)
	end

	def up
		create_table :solution_article_bodies do |t|
			t.integer  "account_id",   :limit => 8, :null => false
			t.integer  "article_id",   :limit => 8, :null => false
			t.text     "description", :limit => 16.megabytes + 1
			t.text     "desc_un_html", :limit => 16.megabytes + 1
			t.timestamps
		end

		add_index :solution_article_bodies, [:account_id, :article_id], :name => 'index_solution_article_bodies_on_account_id_and_article_id', :unique => true
	end

	def down
		drop_table :solution_article_bodies
	end
end
