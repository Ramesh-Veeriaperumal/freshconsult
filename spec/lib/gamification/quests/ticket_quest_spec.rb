require 'spec_helper'
include Gamification::Quests::Constants
include Gamification::Scoreboard::Constants

RSpec.describe Gamification::Quests::ProcessTicketQuests do
  self.use_transactional_fixtures = false
  
  before(:all) do
    #@account = create_test_account
    @account.quests.ticket_quests.each { |quest| quest.destroy } # destroying default ticket quests
    FAST_RESOLUTION_POINTS = @account.scoreboard_ratings.find_by_resolution_speed(FAST_RESOLUTION).score
    FIRST_CALL_RESOLUTION_POINTS = @account.scoreboard_ratings.find_by_resolution_speed(FIRST_CALL_RESOLUTION).score
    HAPPY_CUSTOMER_POINTS = @account.scoreboard_ratings.find_by_resolution_speed(HAPPY_CUSTOMER).score
    OVERALL_RESOLUTION_POINTS = FAST_RESOLUTION_POINTS + FIRST_CALL_RESOLUTION_POINTS
  end
  
  # Assuming all the tickets are resolved fast and in first call
  # Quest_data value has the no of tickets to be resolved and the time span
  
  context "Ticket quests with filter condition - source as email and time span - any time" do 
    before(:all) do
      Resque.inline = false
      quest_filter_data = {
        :and_filters => [{ :name => "source" , :operator => "is", :value => "1"}], # Source "1" is "email"
        :or_filters => [],
        :actual_data => [{ :name => "source" , :operator => "is", :value => "1"}]
      }
      quest_data = {:value => "2", :date => TIME_TYPE_BY_TOKEN[:any_time]}
      @quest = create_ticket_quest(@account, quest_data, quest_filter_data)
      @agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => true})
    end
    
    before(:each) do
      @agent.reload
    end
  
    it "must not achieve the quest when the quest_data value is not satisfied but filter condition is satisfied" do
      Resque.inline = false
      ticket = create_ticket({:status => 2, :responder_id => @agent.user_id, :source => 1})
      Resque.inline = true
      ticket.update_attributes(:status => 4)
      ticket.reload
      @agent.reload
      expected_agent_points = OVERALL_RESOLUTION_POINTS
      @agent.points.should eql(expected_agent_points)
      @agent.achieved_quests.should be_empty
    end
    
    it "must not achieve the quest when the quest_data value is satisfied but filter condition is not satisfied" do
      Resque.inline = false
      ticket = create_ticket({:status => 2, :responder_id => @agent.user_id})
      Resque.inline = true
      ticket.update_attributes(:status => 4)  # Status changed to resolved
      ticket.reload
      @agent.reload
      expected_agent_points = 2 * OVERALL_RESOLUTION_POINTS # 2 tickets have been resolved till the point
      @agent.points.should eql(expected_agent_points)
      @agent.achieved_quests.should be_empty
    end
    
    it "must achieve the quest when the quest_data value and quest filter conditions are satisfied" do
      Resque.inline = false
      ticket = create_ticket({:status => 2, :source => 1, :responder_id => @agent.user_id})
      Resque.inline = true
      ticket.update_attributes(:status => 4) # Status changed to resolved
      ticket.reload
      @agent.reload
      
      # Check if support score with scorable type 'Quest' is created
      @quest.support_scores.should_not be_empty
      @quest.support_scores.first.score.should eql(@quest.points)
      
      # Check if the agent has achieved the correct quests
      @agent.achieved_quests.should_not be_empty
      @agent.achieved_quests.first.quest_id.should eql(@quest.id)
      
      # Check if agent points and level are correct
      expected_agent_points = (3 * (OVERALL_RESOLUTION_POINTS)) + @quest.points # 3 tickets have been resolved till the point
      @agent.points.should eql(expected_agent_points)
      level = @account.scoreboard_levels.level_for_score(@agent.points).first
      @agent.scoreboard_level_id.should eql(level.id) if level
    end
    
    it "must revoke the achieved quests if any of the resolved tickets is reopened again and the quest conditions and data are not satisfied" do
      all_tickets = @account.tickets.find_all_by_responder_id(@agent.user_id)
      ticket = all_tickets.first
      achieved_quest_created_at = @agent.achieved_quests.first.created_at
      ticket.resolved?.should be true
      current_agent_points = @agent.points
      Resque.inline = true
      ticket.update_attributes(:status => 2) # Status changed from resolved to open again
      ticket.reload
      @agent.reload
      expected_agent_points = current_agent_points - @quest.points - OVERALL_RESOLUTION_POINTS
      @agent.achieved_quests.should be_empty
      @quest.support_scores.count.should eql(2)
      @quest.support_scores.last.created_at.should eql(achieved_quest_created_at)
      @agent.points.should eql(expected_agent_points)
    end
  end
  
  context "Ticket quests with filter conditions - customer satisfaction rating is happy and time span - 1 day" do
    before(:all) do
      Resque.inline = false
      quest_filter_data = {
        :and_filters => [{ :name => "st_survey_rating" , :operator => "is", :value => "1"}], # Survey rating "1" is "happy"
        :or_filters => [],
        :actual_data => [{ :name => "st_survey_rating" , :operator => "is", :value => "1"}]
      }
      quest_data = {:value => "2", :date => TIME_TYPE_BY_TOKEN[:one_day]}
      @quest = create_ticket_quest(@account, quest_data, quest_filter_data)
      @agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => true})
    end
    
    before(:each) do
      @agent.reload
    end
    
    it "must not achieve the quest when the quest_data value is not satisfied but filter condition is satisfied" do
      Resque.inline = false
      ticket = create_ticket({:status => 2, :responder_id => @agent.user_id, :source => 2})
      Resque.inline = true
      note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @agent.user_id})
      note.save_note
      send_while = rand(1..4)
      s_handle = create_survey_handle(ticket, send_while, note) 
      s_result = s_handle.create_survey_result(Survey::HAPPY)
      ticket.update_attributes(:status => 4) # Status changed to resolved
      ticket.reload
      @agent.reload
      expected_agent_points = OVERALL_RESOLUTION_POINTS + HAPPY_CUSTOMER_POINTS
      @agent.points.should eql(expected_agent_points)
      @agent.achieved_quests.should be_empty
    end
    
    it "must achieve the quest when the quest_data value and quest filter conditions are satisfied" do
      Resque.inline = false
      ticket = create_ticket({:status => 2, :source => 2, :responder_id => @agent.user_id})
      Resque.inline = true
      note = ticket.notes.build({ :note_body_attributes => {:body => Faker::Lorem.sentence} , :user_id => @agent.user_id})
      note.save_note
      send_while = rand(1..4)
      s_handle = create_survey_handle(ticket, send_while, note) 
      s_result = s_handle.create_survey_result(Survey::HAPPY)
      ticket.update_attributes(:status => 4) # Status changed to resolved
      ticket.reload
      @agent.reload
      
      # Check if support score with scorable type 'Quest' is created
      @quest.support_scores.should_not be_empty
      @quest.support_scores.first.score.should eql(@quest.points)
      
      # Check if the agent has achieved the correct quests
      @agent.achieved_quests.should_not be_empty
      @agent.achieved_quests.first.quest_id.should eql(@quest.id)
      
      # Check if agent points and level are correct
      expected_agent_points = (2 * (OVERALL_RESOLUTION_POINTS + HAPPY_CUSTOMER_POINTS)) + @quest.points # 2 tickets have been resolved till the point
      @agent.points.should eql(expected_agent_points)
      level = @account.scoreboard_levels.level_for_score(@agent.points).first
      @agent.scoreboard_level_id.should eql(level.id) if level
    end
  
    it "must revoke the achieved quests if any of the resolved tickets is reopened again and quest data is not satisfied" do
      all_tickets = @account.tickets.find_all_by_responder_id(@agent.user_id)
      ticket = all_tickets.last
      ticket.resolved?.should be true
      current_agent_points = @agent.points
      achieved_quest_created_at = @agent.achieved_quests.first.created_at
      Resque.inline = true
      ticket.update_attributes(:status => 2) # Status changed from resolved to open again
      ticket.reload
      @agent.reload
      expected_agent_points = current_agent_points - OVERALL_RESOLUTION_POINTS - @quest.points
      @agent.achieved_quests.should be_empty
      @quest.support_scores.last.created_at.should eql(achieved_quest_created_at)
      @agent.points.should eql(expected_agent_points)
    end
  end
end