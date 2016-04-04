require 'spec_helper'

describe Helpdesk::SurveysController do 

  # integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @group = @account.groups.first
    user = add_test_agent(@account)
  end

  before(:each) do
    log_in(@agent)
    login_admin
  end

  it "should create a ticket" do
  		@survey_result = @test_ticket.survey_results.create({        
			:survey_id => 1,                
			:surveyable_type => "Helpdesk::Ticket",
			:customer_id => 4,
			:agent_id => "",
			:group_id => 4,                
			:rating => 1
		})
    #add feedback
    feedback = "Thank you for your valuable feedback"
    @survey_result.add_feedback(feedback) unless feedback.blank?
    @survey_result.id.should_not eql nil
  end
	
end