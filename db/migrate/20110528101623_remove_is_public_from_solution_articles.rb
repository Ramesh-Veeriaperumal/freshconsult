class RemoveIsPublicFromSolutionArticles < ActiveRecord::Migration
  def self.up
    remove_column :solution_articles, :is_public
  end

  def self.down
    add_column :solution_articles, :is_public, :boolean
  end
end
