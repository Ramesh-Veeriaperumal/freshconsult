require 'spec_helper'

describe Support::HomeController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = @account.users.find_by_email("customer@customer.in")
    @test_category = create_category( {:name => "category", :description => "new category", :is_default => false} )
    @test_folder1 = create_folder( {:name => "folder1", :description => "new folder", :visibility => 1,
      :category_id => @test_category.id } )
    @test_folder2 = create_folder( {:name => "folder2 visible to agents", :description => "new folder", :visibility => 3,
      :category_id => @test_category.id } )
    @test_folder3 = create_folder( {:name => "folder3 visible to logged in customers", :description => "new folder", :visibility => 2,
      :category_id => @test_category.id } )
    @test_article1 = create_article( {:title => "article1", :description => "new test article", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1" } )
    @test_article2 = create_article( {:title => "article2 with status as draft", :description => "new test article", :folder_id => @test_folder1.id, 
      :status => "1", :art_type => "1" } )
  end

  before(:each) do
    @request.host = @account.full_domain
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

end