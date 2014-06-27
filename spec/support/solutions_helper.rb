require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module SolutionsHelper

  def create_category(params = {})
    test_category = Factory.build(:solution_categories, :name => params[:name],
              :description => params[:description], :is_default => params[:is_default])
    test_category.account_id = @account.id
    test_category.save(false)
    test_category
  end

  def create_folder(params = {})
    test_folder = Factory.build(:solution_folders, :name => params[:name],
              :description => params[:description], :visibility => params[:visibility], :category_id => params[:category_id])
    test_folder.account_id = @account.id
    test_folder.save(false)
    test_folder
  end

  def create_article(params = {})
    test_article = Factory.build(:solution_articles, :title => params[:title], :description => params[:description],
      :folder_id => params[:folder_id], :status => params[:status], :art_type => params[:art_type])
    test_article.account_id = @account.id
    test_article.user_id = params[:user_id] || @agent.id
    test_article.save(false)
    test_article
  end

end