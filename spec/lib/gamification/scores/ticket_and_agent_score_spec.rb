
require 'spec_helper'
include Gamification::Scoreboard::Constants

describe "Ticket and Agent score specs" do
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account  = create_test_account
  end
  
  context "For first call resolution and fast resolution of tickets" do
    before(:all) do
      Resque.inline = false
      @agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => true})
      @agent.points.should be_nil
      test_ticket = create_ticket({:status => 2, :responder_id => @agent.user_id})
      Resque.inline = true
      @ticket =  @account.tickets.find(test_ticket.id)
      @ticket.update_attributes(:status => 4) # Status changed to resolved
      @ticket.reload
      @fast_rating = @ticket.account.scoreboard_ratings.find_by_resolution_speed(FAST_RESOLUTION)
      @first_call_rating = @ticket.account.scoreboard_ratings.find_by_resolution_speed(FIRST_CALL_RESOLUTION)
    end
    
    before(:each) do
      @agent.reload
      @ticket.reload
    end
    
    it "must create the support scores for the tickets" do
      support_scores = @ticket.support_scores
      support_scores.should_not be_empty
      
      sorted_scores = support_scores.sort_by {|score| score.score_trigger }
      sorted_scores.first.score_trigger.should eql(@fast_rating.resolution_speed)
      sorted_scores.first.score.should eql(@fast_rating.score)
      
      sorted_scores.second.score_trigger.should eql(@first_call_rating.resolution_speed)
      sorted_scores.second.score.should eql(@first_call_rating.score)
    end
    
    it "must assign the points for the agent" do
      overall_support_score = @ticket.support_scores.sum(:score)
      @agent.points.should eql(overall_support_score.to_int)
    end
    
    after(:all) do
      Resque.inline = false
      @ticket.destroy
      @agent.user.destroy
    end
  end
  
  context "For on time resolution of tickets" do
    before(:all) do
      @agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => true})
      @agent.points.should be_nil
      test_ticket = create_ticket({:status => 2, :responder_id => @agent.user_id, :created_at => (Time.zone.now - 3.hours)})
      @ticket =  @account.tickets.find(test_ticket.id)
      note = @ticket.notes.build({
        :note_body_attributes => { :body => Faker::Lorem.sentence(3)},
        :private => false,
        :incoming => true,
        :source     => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email],
        :account_id => @ticket.account_id,
        :user_id => @ticket.requester.id
      })
      note.save
      Resque.inline = true
      @ticket.update_attributes(:status => 4) # Status changed to resolved
      @ticket.reload
      @on_time_rating = @ticket.account.scoreboard_ratings.find_by_resolution_speed(ON_TIME_RESOLUTION)
    end
    
    before(:each) do
      @agent.reload
      @ticket.reload
    end
    
    it "must create the support scores for the tickets" do
      support_scores = @ticket.support_scores
      support_scores.should_not be_empty
      
      sorted_scores = support_scores.sort_by {|score| score.score_trigger }
      sorted_scores.first.score_trigger.should eql(@on_time_rating.resolution_speed)
      sorted_scores.first.score.should eql(@on_time_rating.score)
    end
    
    it "must assign the points for the agent" do
      overall_support_score = @ticket.support_scores.sum(:score)
      @agent.points.should eql(overall_support_score.to_int)
    end
    
    after(:all) do
      Resque.inline = false
      @ticket.destroy
      @agent.user.destroy
    end
  end
  
  context "For reopened tickets" do 
    before(:all) do
      Resque.inline = false
      @agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => true})
      @agent.points.should be_nil
      test_ticket = create_ticket({:status => 2, :responder_id => @agent.user_id})
      Resque.inline = true
      @ticket =  @account.tickets.find(test_ticket.id)
      @ticket.update_attributes(:status => 4) # Status changed to resolved
      @ticket.reload
      @ticket.update_attributes(:status => 2) # Status again changed to open
    end
    
    before(:each) do
      @agent.reload
      @ticket.reload
    end
    
    it "must remove the existing support scores for the tickets" do
      support_scores = @ticket.support_scores
      support_scores.should be_empty
    end
    
    it "must remove the points for the agents" do
      @agent.points.should be_zero
    end
    
    after(:all) do
      Resque.inline = false
      @agent.user.destroy
      @ticket.destroy
    end
  end
  
  context "For late resolution of tickets " do
    it "must create the support scores for tickets"
  end
  
  context "For Happy customer" do
    before(:all) do
      Resque.inline = false
      @agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => true})
      @agent.points.should be_nil
      test_ticket = create_ticket({:status => 2, :responder_id => @agent.user_id})
      Resque.inline = true
      @ticket =  @account.tickets.find(test_ticket.id)
      note = @ticket.notes.create({:body => Faker::Lorem.sentence, :user_id => @agent.user_id})
      send_while = rand(1..4)
      s_handle = create_survey_handle(@ticket, send_while, note) 
      s_result = s_handle.create_survey_result(Survey::HAPPY)
      @happy_rating = @ticket.account.scoreboard_ratings.find_by_resolution_speed(HAPPY_CUSTOMER)
    end
    
    before(:each) do
      @agent.reload
      @ticket.reload
    end

    it "must create the support scores for the ticket" do
      support_scores = @ticket.support_scores
      support_scores.should_not be_empty
      support_scores.first.score_trigger.should eql(@happy_rating.resolution_speed)
      support_scores.first.score.should eql(@happy_rating.score)
    end
    
    it "must add the points for the tables" do
      overall_support_score = @ticket.support_scores.sum(:score)
      @agent.points.should eql(overall_support_score.to_int)
    end
    
    after(:all) do
      Resque.inline = false
      @ticket.destroy
      @agent.user.destroy
    end
  end
  
  
  context "For Unhappy customer" do
    before(:all) do
      Resque.inline = false
      @agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => true})
      @agent.points.should be_nil
      test_ticket = create_ticket({:status => 2, :responder_id => @agent.user_id})
      Resque.inline = true
      @ticket =  @account.tickets.find(test_ticket.id)
      note = @ticket.notes.create({:body => Faker::Lorem.sentence, :user_id => @agent.user_id})
      send_while = rand(1..4)
      s_handle = create_survey_handle(@ticket, send_while, note) 
      s_result = s_handle.create_survey_result(Survey::UNHAPPY)
      @unhappy_rating = @ticket.account.scoreboard_ratings.find_by_resolution_speed(UNHAPPY_CUSTOMER)
    end
    
    before(:each) do
      @agent.reload
      @ticket.reload
    end

    it "must create the support scores for the ticket" do
      support_scores = @ticket.support_scores
      support_scores.should_not be_empty
      support_scores.first.score_trigger.should eql(@unhappy_rating.resolution_speed)
      support_scores.first.score.should eql(@unhappy_rating.score)
    end
    
    it "must add the points for the tables" do
      overall_support_score = @ticket.support_scores.sum(:score)
      @agent.points.should eql(overall_support_score.to_int)
    end
    
    after(:all) do
      Resque.inline = false
      @ticket.destroy
      @agent.user.destroy
    end
  end
end