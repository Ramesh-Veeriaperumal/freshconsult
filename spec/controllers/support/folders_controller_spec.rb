require 'spec_helper'

describe Support::Solutions::FoldersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
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

  it "should render 404 for default folder" do
    log_in(@user)
    default_folder = create_folder( {:name => "#{Faker::Lorem.sentence(3)}", 
                             :description => "#{Faker::Lorem.sentence(3)}",  
                             :visibility => 1,
                             :category_id => @test_category.id,
                             :is_default => true } )
    get 'show', id: default_folder
    response.status.should eql(404)
  end

  it "should render 404 for folders not visible in current portal" do 
    portal = create_portal
    category = create_category({:portal_ids => [portal.id]})
    folder = create_folder({:visibility => 1, :category_id => category.id })
    get 'show', :id => folder
    response.status.should eql(404)
  end
  
end