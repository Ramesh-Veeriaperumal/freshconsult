require 'spec_helper'

describe Support::Solutions::FoldersController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
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

  it "should not show folder1 without logging in" do
    get 'show', id: @test_folder1
    response.body.should =~ /redirected/
    response.body.should_not =~ /folder1 visible to logged in customers/
  end

  it "should not show folder2 without logging in" do
    get 'show', id: @test_folder2
    response.body.should =~ /redirected/
    response.body.should_not =~ /folder2 visible to agents/
  end

  it "should show folder1" do
    log_in(@user)
    get 'show', id: @test_folder1
    response.body.should =~ /folder1 visible to logged in customers/
  end

  it "should not show folder2" do
    log_in(@user)
    get 'show', id: @test_folder2
    response.body.should =~ /redirected/
    response.body.should_not =~ /folder2 visible to agents/
  end

end