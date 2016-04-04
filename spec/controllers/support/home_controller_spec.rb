require 'spec_helper'

describe Support::HomeController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    now = "#{Time.now.to_f}"
    @test_category = create_category( {:name => "category - #{now}", :description => "new category", :is_default => false} )
    @test_folder1 = create_folder( {:name => "folder1 - #{now}", :description => "new folder", :visibility => 1,
      :category_id => @test_category.id } )
    @test_folder2 = create_folder( {:name => "folder2 visible to agents - #{now}", :description => "new folder", :visibility => 3,
      :category_id => @test_category.id } )
    @test_folder3 = create_folder( {:name => "folder3 visible to logged in customers - #{now}", :description => "new folder", :visibility => 2,
      :category_id => @test_category.id } )
    @test_article1 = create_article( {:title => "article1 - #{now}", :description => "new test article", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1", :user_id => @agent.id } )
    @test_article2 = create_article( {:title => "article2 with status as draft - #{now}", :description => "new test article", :folder_id => @test_folder1.id, 
      :status => "1", :art_type => "1", :user_id => @agent_id } )
  end

  before(:each) do
    @account.features.open_solutions.create
  end

  it "should show folder1 without logging in" do
    get 'index'
    response.body.should =~ /folder1/
  end

  it "should not show folder3 without logging in" do
    @account.features.open_solutions.destroy
    get 'index'
    response.body.should_not =~ /folder3 visible to logged in customers/
  end

  it "should not show folder2 without logging in" do
    @account.features.open_solutions.destroy
    get 'index'
    response.body.should_not =~ /folder2 visible to agents/
  end

  it "should not show solutions" do
    @account.features.open_solutions.destroy
    get 'index'
    response.body.should_not =~ /Solutions/
  end

  it "should show category" do
    log_in(@user)
    get 'index'
    response.body.should =~ /category/
  end

  it "should show folder" do
    log_in(@user)
    get 'index'
    response.body.should =~ /folder1/
  end

  it "should show folder visible to logged in customers" do
    log_in(@user)
    get 'index'
    response.body.should =~ /folder3 visible to logged in customers/
  end

  it "should show article" do
    log_in(@user)
    get 'index'
    response.body.should =~ /article1/
  end

  it "should not show folder visible to agents" do
    log_in(@user)
    get 'index'
    response.body.should_not =~ /folder2 visible to agents/
  end

  it "should not show article with status as draft" do
    log_in(@user)
    get 'index'
    response.body.should_not =~ /article2 with status as draft/
  end

  it "should redirect to login page if the account has open_forums feature without having forums and solutions" do
    @account.features.open_solutions.destroy
    @account.features.open_forums.create
    @account.features.forums.destroy
    get 'index'
    response.should redirect_to support_login_url
  end
end