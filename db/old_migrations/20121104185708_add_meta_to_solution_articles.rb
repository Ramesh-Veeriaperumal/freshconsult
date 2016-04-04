class AddMetaToSolutionArticles < ActiveRecord::Migration
  def self.up
    add_column :solution_articles, :seo_data, :text
    Solution::Article.update_all({:seo_data => {}.to_yaml})
  end

  def self.down
    remove_column :solution_articles, :seo_data
  end
end
