class AddDescHtmlToSolutionArticles < ActiveRecord::Migration
  def self.up
    add_column :solution_articles, :desc_un_html, :text , :limit => 16777215
  end

  def self.down
    remove_column :solution_articles, :desc_un_html
  end
end
