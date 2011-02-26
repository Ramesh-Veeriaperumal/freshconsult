class AddThumbsUpToSolutionArticle < ActiveRecord::Migration
  def self.up
    add_column :solution_articles, :thumbs_up, :integer,:default => 0
  end

  def self.down
    remove_column :solution_articles, :thumbs_up
  end
end
