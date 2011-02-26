class AddThumbsDownToSolutionArticle < ActiveRecord::Migration
  def self.up
    add_column :solution_articles, :thumbs_down, :integer,:default => 0
  end

  def self.down
    remove_column :solution_articles, :thumbs_down
  end
end
