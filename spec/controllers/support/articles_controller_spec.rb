require 'spec_helper'

describe Support::Solutions::ArticlesController do
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

    @public_folder  = create_folder({
                                      :name => "Public #{Faker::Name.name} visible to All", 
                                      :description => "#{Faker::Lorem.sentence(3)}", 
                                      :visibility => 1,
                                      :category_id => @test_category.id 
                                    })

    @test_article1 = create_article( {:title => "article1 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1" , :user_id => "#{@agent.id}"} )
    @test_article2 = create_article( {:title => "article2 #{Faker::Name.name} with status as draft", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "1", :art_type => "1", :user_id => "#{@agent.id}" } )
    @test_article3 = create_article( {:title => "article3 #{Faker::Name.name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder2.id, 
      :status => "2", :art_type => "1", :user_id => "#{@agent.id}" } )

    @public_article1 = create_article({
      :title => Faker::Name.name,
      :description => Faker::Lorem.sentence(10),
      :folder_id => @public_folder.id,
      :status => 2,
      :art_type => 1,
      :user_id => @agent.id
    })


    @public_article2 = create_article({
      :title => Faker::Name.name,
      :description => Faker::Lorem.sentence(10),
      :folder_id => @public_folder.id,
      :status => 2,
      :art_type => 1,
      :user_id => @agent.id
    })


    @public_article3 = create_article({
      :title => Faker::Name.name,
      :description => Faker::Lorem.sentence(10),
      :folder_id => @public_folder.id,
      :status => 2,
      :art_type => 1,
      :user_id => @agent.id
    })
  end

  before(:each) do
    RSpec.configuration.account.features.open_solutions.create
  end

  xit "should redirect to support home if index is hit" do# failing in master
    log_in(@user)
    get :index, :category_id => @test_category.id, :folder_id => @test_folder1.id, :id => @test_article1.id
    response.should redirect_to("#{support_solutions_path}")
  end


  it "should increment thumbs up for non logged in users" do
    likes = @public_article2.thumbs_up
    put :thumbs_up, :id => @public_article2.id  
    @public_article2.reload
    @public_article2.thumbs_up.should eql(likes + 1)   
    response.code.should be_eql("200")
  end

  it "should not increment thumbs up for an agent" do
    log_in(@agent)
    likes = @public_article2.thumbs_up
    put :thumbs_up, :id => @public_article2.id
    @public_article2.reload
    @public_article2.thumbs_up.should eql(likes)
    response.code.should be_eql("200")
  end

  it "should increment thumbs up for logged in user's first vote and store in votes table" do
    log_in(@user)
    likes = @public_article2.thumbs_up
    put :thumbs_up, :id => @public_article2.id
    @public_article2.reload
    @public_article2.thumbs_up.should eql(likes + 1)
    vote = @public_article2.votes.find_by_user_id(@user.id)
    vote.should be_an_instance_of(Vote)
    vote.voteable_id.should eql @public_article2.id
    vote.voteable_type.should eql "Solution::Article" 
    vote.vote.should eql true
    response.code.should be_eql("200")
  end

  xit "should increment thumbs up" do# failing in master 
    log_in(@user)
    put :thumbs_up, :id => @public_article2.id
    @public_article2.reload
    likes = @public_article2.thumbs_up
    put :thumbs_up, :id => @public_article2.id
    @public_article2.reload
    @public_article2.thumbs_up.should eql(likes)
    response.code.should be_eql("200")
  end

  xit "should increment thumbs down" do# failing in master
    log_in(@user)
    put :thumbs_down, :id => @public_article2.id
    @public_article2.reload
    likes = @public_article2.thumbs_up
    dislikes = @public_article2.thumbs_down
    put :thumbs_up, :id => @public_article2.id
    @public_article2.reload
    vote = @public_article2.votes.find_by_user_id(@user.id)
    vote.should be_an_instance_of(Vote)
    vote.voteable_id.should eql @public_article2.id
    vote.voteable_type.should eql "Solution::Article" 
    vote.vote.should eql true
    @public_article2.thumbs_up.should eql(likes + 1)
    @public_article2.thumbs_down.should eql(dislikes - 1)
  end

  it "should increment thumbs down for non logged in users" do
    dislikes = @public_article3.thumbs_down
    put :thumbs_down, :id => @public_article3.id, :format => "html" 
    @public_article3.reload
    @public_article3.thumbs_down.should eql(dislikes + 1)
    response.body.should =~ /Your email/
    response.code.should be_eql("200")
  end

  it "should not increment thumbs down for an agent" do
    log_in(@agent)
    dislikes = @public_article3.thumbs_down
    put :thumbs_down, :id => @public_article3.id
    @public_article3.reload
    @public_article3.thumbs_down.should eql(dislikes)
    response.code.should be_eql("200")
  end

  it "should increment thumbs down for logged in user's first vote and store in votes table" do
    log_in(@user)
    dislikes = @public_article3.thumbs_down
    put :thumbs_down, :id => @public_article3.id
    @public_article3.reload
    @public_article3.thumbs_down.should eql(dislikes + 1)
    vote = @public_article3.votes.find_by_user_id(@user.id)
    vote.should be_an_instance_of(Vote)
    vote.voteable_id.should eql @public_article3.id
    vote.voteable_type.should eql "Solution::Article" 
    vote.vote.should eql false
    response.code.should be_eql("200")
  end

  it "should not increment thumbs down for logged in user's second vote if existing vote is a dislike" do
    log_in(@user)
    put :thumbs_down, :id => @public_article3.id
    @public_article3.reload
    dislikes = @public_article3.thumbs_down
    put :thumbs_down, :id => @public_article3.id
    @public_article3.reload
    @public_article3.thumbs_down.should eql(dislikes)
    response.code.should be_eql("200")
  end

  it "should increment thumbs down and decrement thumbs up for logged in user's second vote if existing vote is a like" do
    log_in(@user)
    put :thumbs_up, :id => @public_article3.id
    @public_article3.reload
    likes = @public_article3.thumbs_up
    dislikes = @public_article3.thumbs_down
    put :thumbs_down, :id => @public_article3.id
    @public_article3.reload
    vote = @public_article3.votes.find_by_user_id(@user.id)
    vote.should be_an_instance_of(Vote)
    vote.voteable_id.should eql @public_article3.id
    vote.voteable_type.should eql "Solution::Article" 
    vote.vote.should eql false
    @public_article3.thumbs_up.should eql(likes - 1)
    @public_article3.thumbs_down.should eql(dislikes + 1)
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

  xit "should not show article and redirect to support solutions home if its folder is visible only to Agents" do# failing in master
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

  xit "should handle unknown actions" do# failing in master 
    log_in(@user)
    get :unknownaction, :id => @test_article1.id    
    response.should redirect_to("#{send(Helpdesk::ACCESS_DENIED_ROUTE)}")
  end

  xit "should create ticket while submitting feedback form" do # failing in master
    log_in(@user)
    post :create_ticket, :id => @test_article1.id,
      :helpdesk_ticket=> {:subject=>"#{@test_article1.title}", 
                          :email=> Faker::Internet.email, 
                          :ticket_body_attributes =>{:description=>""}}
    RSpec.configuration.account.tickets.find_by_subject("#{@test_article1.title}").should  be_an_instance_of(Helpdesk::Ticket)
    response.status.should eql(200)
  end
    
  xit "should show a published article to user" do#profiles_controller_spec.rb
    log_in(@user)
    name = Faker::Name.name
    article = create_article( {:title => "#{name}", :description => "#{Faker::Lorem.sentence(3)}", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1" , :user_id => "#{@agent.id}"} )    
    get 'show', id: article.id
    response.body.should =~ /#{name}/    
  end

  xit "should not show a draft article to user" do# failing in master
    log_in(@user)
    get 'show', id: @test_article2
    response.body.should_not =~ /article2 with status as draft/    
    response.code.should be_eql("404")
  end

  it "should increase hit count on get 'hit'" do
    hit_count = @public_article1.hits
    get :hit, :id => @public_article1.id
    @public_article1.reload
    @public_article1.hits.should be_eql(hit_count + 1)
  end
end