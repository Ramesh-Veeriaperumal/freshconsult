class AddDeltaToSolutionArticles < ActiveRecord::Migration
  def self.up
    add_column :solution_articles, :delta, :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :solution_articles, :delta
  end
end
