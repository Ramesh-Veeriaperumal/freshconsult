require 'spec_helper'

describe SurveyHandle do 

	before(:all) do
    setup_data
    @new_agent = add_agent_to_account(@account, {:name => "testing", :email => Faker::Internet.email,
                                                 :active => 1, :role => 4,
                                                 :group_id => @group.id})


    @new_ticket = create_ticket({:status => 2}, @group)
    @another_ticket = create_ticket({:status => 2}, @group)
  end

  before(:each) do
    @ticket.responder_id = nil
    @ticket.save!
    @new_ticket.responder_id = nil
    @new_ticket.save!
  end


  def setup_data
    @group = create_group(@account,{:ticket_assign_type => 1, :name =>  "dummy group"})
    @group.ticket_assign_type = 1
    @group.save!

    @agent = add_agent_to_account(@account, {:name => "testing2", :email => Faker::Internet.email,
                                             :active => 1, :role => 1
                                            })
    @agent.available = 1
    @agent.save!

    ag_grp = AgentGroup.new(:user_id => @agent.user_id , :account_id =>  @account.id, :group_id => @group.id)
    ag_grp.save!

    @ticket = create_ticket({:status => 2}, @group)
    @ticket.group_id = @group.id
    @ticket.save!
  end


  it "should create survey result" do
    survey =  @account.custom_surveys.first
  	test_result= @ticket.survey_results.create({
      :account_id => @account.id,
      :survey_id => survey.id,
      :surveyable_id => @ticket.id,
      :surveyable_type => "Helpdesk::Ticket",
      :customer_id => "3",
      :agent_id => @agent.id,
      :group_id => @group.id,
      :response_note_id => "1" ,
      :rating => CustomSurvey::Survey::EXTREMELY_HAPPY
    })
    test_result.id.should_not eql nil
  end
end