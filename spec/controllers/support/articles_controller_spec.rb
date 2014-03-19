require 'spec_helper'

describe Support::Solutions::ArticlesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = @account.users.find_by_email("customer@customer.in")
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "category #{@now}", :description => "new category", :is_default => false} )
    @test_folder1 = create_folder( {:name => "folder1 visible to logged in customers", :description => "new folder", :visibility => 2,
      :category_id => @test_category.id } )
    @test_folder2 = create_folder( {:name => "folder2 visible to agents", :description => "new folder", :visibility => 3,
      :category_id => @test_category.id } )
    @test_article1 = create_article( {:title => "article1", :description => "new test article", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1" } )
    @test_article2 = create_article( {:title => "article2 with status as draft", :description => "new test article", :folder_id => @test_folder1.id, 
      :status => "1", :art_type => "1" } )
  end

  before(:each) do
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                       (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    @request.host = @account.full_domain
    @account.features.open_solutions.create
  end

  it "should not show article without logging in" do
    @account.features.open_solutions.destroy
    get 'show', id: @test_article1
    response.body.should_not =~ /article1/
  end

  it "should not show draft article without logging in" do
    @account.features.open_solutions.destroy
    get 'show', id: @test_article2
    response.body.should_not =~ /article2 with status as draft/
  end

  it "should show article1" do
    log_in(@user)
    get 'show', id: @test_article1
    response.body.should =~ /article1/
  end

  it "should not show article2" do
    log_in(@user)
    get 'show', id: @test_article2
    response.body.should_not =~ /article2 with status as draft/
  end

end