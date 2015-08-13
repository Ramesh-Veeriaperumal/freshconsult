require 'spec_helper'

describe Support::SolutionsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "category #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_category2 = create_category( {:name => "category2 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_folder1 = create_folder( {:name => "folder1 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
      :category_id => @test_category.id } )
    @test_folder2 = create_folder( {:name => "folder2 visible to agents #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 3,
      :category_id => @test_category.id } )
    @test_folder3 = create_folder( {:name => "folder3 visible to logged in customers#{Faker::Name.name} ", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 2,
      :category_id => @test_category.id } )
    @test_article1 = create_article( {:title => "article1 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1", :user_id => "#{@agent.id}"  } )
    @test_article2 = create_article( {:title => "article2 #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "1", :art_type => "1", :user_id => "#{@agent.id}"  } )
  end

  before(:each) do
    @account.features.open_solutions.create
  end

  it "should show folder without logging in" do
    get 'index'
    response.body.should =~ /folder1/
    response.should render_template("support/solutions/index")
  end

  it "should not show folder without logging in while open solution feature is disabled" do
    @account.features.open_solutions.destroy
    get 'index'
    response.body.should_not =~ /folder3 visible to logged in customers/
    response.should redirect_to(login_url)    
  end

  it "should not show folder without logging in" do
    get 'index'
    response.body.should_not =~ /folder2 visible to agents/
    response.should redirect_to(login_url)    
  end

  it "should not show solutions" do
    @account.features.open_solutions.destroy
    get 'index'
    response.body.should_not =~ /Solutions/ 
    response.should redirect_to(login_url)    
  end

  it "should show category" do
    log_in(@user)
    get 'index'
    response.body.should =~ /category/
    response.should render_template("support/solutions/index")
  end

  it "should show folder" do
    log_in(@user)
    get 'index'
    response.body.should =~ /folder1/
    response.should render_template("support/solutions/index")
  end

  it "should show folder visible to logged in customers" do
    log_in(@user)
    get 'index'
    response.body.should =~ /folder3 visible to logged in customers/
    response.should render_template("support/solutions/index")
  end

  it "should show article" do
    log_in(@user)
    get 'index'
    response.body.should =~ /article1/
    response.should render_template("support/solutions/index")
  end

  it "should not show folder visible to agents" do
    log_in(@user)
    get 'index'
    response.body.should_not =~ /folder2 visible to agents/
    response.should render_template("support/solutions/index")
  end

  it "should not show article with status as draft" do
    log_in(@user)
    get 'index'
    response.body.should_not =~ /article2 with status as draft/
    response.should render_template("support/solutions/index")
  end

  it "should render show page of test category" do 
    log_in(@user)
    get 'show', :id => @test_category.id
    response.body.should =~ /#{@test_category.name}/
    response.body.should_not =~ /#{@test_category2.name}/
    response.should render_template("support/solutions/show")
  end

  it "should render 404 for default category" do
    log_in(@user)
    default_category = create_category( {:name => "category #{Faker::Name.name}",
                       :description => "#{Faker::Lorem.sentence(3)}", :is_default => true} )
    get 'show', id: default_category.id
    response.status.should eql(404)
  end

end