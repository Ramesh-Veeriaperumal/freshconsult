require 'spec_helper'

describe Support::SurveysController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group = create_group(@account, {:name => "survey"})
  end

  before(:each) do
    login_admin
  end

  it "should not allow to rate a surveyed link" do
    ticket = create_ticket({ :status => 2 }, @group)
    note = ticket.notes.create(:body => Faker::Lorem.sentence)
    send_while = rand(1..4)
    s_handle = create_survey_handle(ticket, send_while, note)
    s_handle.rated = true
    s_handle.save
    rating_type = rand(1..3)

    get :new, :survey_code => s_handle.id_token, :rating => Survey::CUSTOMER_RATINGS[rating_type]
    SurveyHandle.find(s_handle.id).survey_result.should be_nil
  end

  it "should not allow an unathorized user to take a survey" do
    ticket = create_ticket({ :status => 2 }, @group)
    feedback = Faker::Lorem.sentence
    Support::SurveysController.any_instance.stubs(:can_access_support_ticket? => false)
    
    put :create_for_portal, :rating => rand(1..4), 
                            :feedback => feedback, 
                            :ticket_id => ticket.display_id
    ticket.notes.last.should_not be_eql(feedback)
  end
end