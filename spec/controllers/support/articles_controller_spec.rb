require 'spec_helper'

describe Support::Solutions::ArticlesController do
  # integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
    @now = (Time.now.to_f*1000).to_i
    @test_category = create_category( {:name => "test category #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :is_default => false} )
    @test_folder1 = create_folder( {:name => "folder1 #{Faker::Name.name} visible to logged in customers", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 2,
      :category_id => @test_category.id } )
    @test_folder2 = create_folder( {:name => "folder2 #{Faker::Name.name} visible to agents", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 3,
      :category_id => @test_category.id } )
    @test_article1 = create_article( {:title => "article1 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1" , :user_id => "#{@agent.id}"} )
    @test_article2 = create_article( {:title => "article2 #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "1", :art_type => "1", :user_id => "#{@agent.id}" } )
    @test_article3 = create_article( {:title => "article3 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder2.id, 
      :status => "2", :art_type => "1", :user_id => "#{@agent.id}" } )
  end

  before(:each) do
    RSpec.configuration.account.features.open_solutions.create
  end

  it "should redirect to support home if index is hit" do 
    log_in(@user)
    get :index, :category_id => @test_category.id, :folder_id => @test_folder1.id, :id => @test_article1.id
    response.should redirect_to("#{support_solutions_path}")
  end  

  it "should increment thumbs up" do 
    log_in(@user)
    put :thumbs_up, :id => @test_article1.id    
    @test_article1.reload
    @test_article1.thumbs_up.should eql 1    
    response.code.should be_eql("200")
  end

  it "should increment thumbs down" do 
    log_in(@user)
    put :thumbs_down, :id => @test_article1.id, :format => "html" 
    @test_article1.reload
    @test_article1.thumbs_down.should eql 1
    response.body.should =~ /Your email/
    response.code.should be_eql("200")
  end

  it "should redirect to login page if there is no open solutions feature " do
    name = Faker::Name.name
    RSpec.configuration.account.features.open_solutions.destroy
    article = create_article( {:title => "#{name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1" , :user_id => "#{@agent.id}"} )    
    get 'show', id: article.id
    response.body.should_not =~ /#{name}/
    response.should redirect_to(login_url)    
  end

  it "should not show article and redirect to support solutions home if its folder is visible only to Agents" do 
    log_in(@user) 
    get 'show', :id => @test_article3    
    response.should redirect_to(support_solutions_path)    
  end
 
  it "should not show draft article without logging in while open solutions feature is disabled" do
    RSpec.configuration.account.features.open_solutions.destroy
    get 'show', id: @test_article2
    response.body.should_not =~ /article2 with status as draft/
    response.should redirect_to(login_url)    
  end

  it "should handle unknown actions" do 
    log_in(@user)
    get :unknownaction, :id => @test_article1.id    
    response.should redirect_to("#{send(Helpdesk::ACCESS_DENIED_ROUTE)}")
  end

  it "should create ticket while submitting feedback form" do 
    log_in(@user)
    post :create_ticket, :id => @test_article1.id,
      :helpdesk_ticket=> {:subject=>"#{@test_article1.title}", 
                          :email=> Faker::Internet.email, 
                          :ticket_body_attributes =>{:description=>""}}
    @acc.tickets.find_by_subject("#{@test_article1.title}").should  be_an_instance_of(Helpdesk::Ticket)
    response.code.should be_eql("200")
  end
    
  it "should show a published article to user" do
    log_in(@user)
    name = Faker::Name.name
    article = create_article( {:title => "#{name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1" , :user_id => "#{@agent.id}"} )    
    get 'show', id: article.id
    response.body.should =~ /#{name}/    
  end

  it "should not show a draft article to user" do
    log_in(@user)
    get 'show', id: @test_article2
    response.body.should_not =~ /article2 with status as draft/    
    response.code.should be_eql("404")
  end
end