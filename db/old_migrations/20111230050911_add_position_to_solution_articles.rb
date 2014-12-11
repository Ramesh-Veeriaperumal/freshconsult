class AddPositionToSolutionArticles < ActiveRecord::Migration
  def self.up
    add_column :solution_articles, :position, :integer
  end

  def self.down
    remove_column :solution_articles, :position
  end
end
