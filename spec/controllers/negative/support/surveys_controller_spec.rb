require 'spec_helper'

describe Support::SurveysController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group = create_group(@account, {:name => "survey"})
    @user = create_dummy_customer
  end

  before(:each) do
    log_in(@user)
  end

  it "should not allow to rate a surveyed link" do
    ticket = create_ticket({ :status => 2 }, @group)
    @survey = @account.survey
    @survey.update_attributes(send_while: 1)
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @user.id})
    note.save_note
    s_handle = SurveyHandle.create_handle(ticket, note, false)
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