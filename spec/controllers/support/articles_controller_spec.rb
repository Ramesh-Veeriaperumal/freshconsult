require 'spec_helper'

RSpec.describe Support::Solutions::ArticlesController do
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
    @account.features.open_solutions.create
  end

  it "should redirect to support home if index is hit" do
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

  it "should increment thumbs up" do
    log_in(@user)
    put :thumbs_up, :id => @public_article2.id
    @public_article2.reload
    likes = @public_article2.thumbs_up
    put :thumbs_up, :id => @public_article2.id
    @public_article2.reload
    @public_article2.thumbs_up.should eql(likes)
    response.code.should be_eql("200")
  end

  it "should increment thumbs down" do
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
    @account.features.open_solutions.destroy
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
    @account.features.open_solutions.destroy
    get 'show', id: @test_article2
    response.body.should_not =~ /article2 with status as draft/
    response.should redirect_to(login_url)
  end

  it "should handle unknown actions" do
    log_in(@user)
    expect{get :unknownaction, :id => @test_article1.id}.to raise_error(ActionController::RoutingError)  
    # response.should redirect_to("#{send(Helpdesk::ACCESS_DENIED_ROUTE)}")
  end

  it "should create ticket, add watcher and update article_tickets while submitting feedback form for logged in users" do 
    log_in(@user)
    description = Faker::Lorem.paragraph

    random_message = rand(4) + 1
    post :create_ticket, :id => @test_article1.id,
      :helpdesk_ticket_description => "#{description}",
      :message => [random_message]
    response.code.should be_eql("200")
    
    ticket = @acc.tickets.find_by_subject("Article Feedback - #{@test_article1.title}")
    ticket.description.include? description
    ticket.description.include? I18n.t("solution.feedback_message_#{random_message}")
    ArticleTicket.find(:all, :conditions => { :article_id => @test_article1.id }).map(&:ticket_id).should include ticket.id
    ArticleTicket.find_by_ticket_id(ticket).article_id.should eql @test_article1.id
    ticket.subscriptions.find_by_user_id(@test_article1.user_id).should_not be_nil
  end
    
  it "should create ticket and update article_tickets while submitting feedback form for non logged in users" do
    agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => 1, :role => 1 })
    test_article = create_article( {:title => "article #{Faker::Lorem.sentence}", :description => "#{Faker::Lorem.paragraph}", :folder_id => @test_folder1.id, 
      :status => "2", :art_type => "1" , :user_id => "#{agent.id}"} )
    description = Faker::Lorem.paragraph
    
    agent.user.make_customer

		random_message = rand(4) + 1
    post :create_ticket, :id => test_article.id,
      :helpdesk_ticket => { :email => "example@example.com" },
      :helpdesk_ticket_description => description,
      :message => [1]
   
    ticket = @acc.tickets.find_by_subject("Article Feedback - #{test_article.title}")
    ticket.description.include? description
    ticket.description.include? I18n.t("solution.feedback_message_#{random_message}")
    ArticleTicket.find(:all, :conditions => { :article_id => test_article.id }).map(&:ticket_id).should include ticket.id
    ArticleTicket.find_by_ticket_id(ticket).article_id.should eql test_article.id
    ticket.subscriptions.find_by_user_id(test_article.user_id).should be_nil
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

  it "should increase hit count on get 'hit'" do
    log_in(@user)
    hit_count = @public_article1.hits
    get :hit, :id => @public_article1.id
    @public_article1.reload
    @public_article1.hits.should be_eql(hit_count + 1)
  end
end