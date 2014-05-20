require 'spec_helper'

describe Solution::ArticlesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @now = (Time.now.to_f*1000).to_i
    @user = add_test_agent(@account)
    @test_category = create_category( {:name => "new category #{@now}", :description => "new category", :is_default => false} )
    @test_folder = create_folder( {:name => "new folder", :description => "new folder", :visibility => 1,
      :category_id => @test_category.id } )
    @test_article = create_article( {:title => "new article", :description => "new test article", :folder_id => @test_folder.id, 
      :user_id => @user.id, :status => "2", :art_type => "1" } )
  end

  before(:each) do
    log_in(@user)
  end

  it "should create a new solution article" do
    now = (Time.now.to_f*1000).to_i
    post :create, { :solution_article => {:title => "New solution article #{now}",
      :description => "New solution article #{now}" ,:folder_id => @test_folder.id, :status => 2, :art_type => 1},
      :tags => {:name => ""}
    }
    @account.solution_articles.find_by_title("New solution article #{now}").should be_an_instance_of(Solution::Article)
  end

  it "should edit a solution article" do
    put :update, { :id => @test_article.id, 
                   :solution_article => {:title => "new article #{@now}",
                                          :description => "Update solution article #{@now}",
                                          :folder_id => "#{@test_folder.id}", 
                                          :status => "2",
                                          :art_type => "1"
                                          },
                    :tags => {:name => ""},
                    :category_id => @test_category.id, 
                    :folder_id => @test_folder.id 
                  }
    @account.solution_articles.find_by_title("new article #{@now}").should be_an_instance_of(Solution::Article)
  end

  it "should delete a solution article" do
    title = @test_article.title
    delete :destroy, :id => @test_article.id
    @account.solution_articles.find_by_title(title).should be_nil
  end

end