class AddAccountIdToSolutionArticles < ActiveRecord::Migration
  def self.up
    add_column :solution_articles, :account_id, :integer
  end

  def self.down
    remove_column :solution_articles, :account_id
  end
end
