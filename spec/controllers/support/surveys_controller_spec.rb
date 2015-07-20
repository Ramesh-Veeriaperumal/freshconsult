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

  it "should create a new survey handle" do 
    ticket = create_ticket({ :status => 2 }, @group)
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @user.id})
    note.save_note
    send_while = rand(1..4)

    s_handle = create_survey_handle(ticket, send_while, note)
    rating_type = rand(1..3)

    get :new, :survey_code => s_handle.id_token, :rating => Survey::CUSTOMER_RATINGS[rating_type]
    response.should be_success
    response.body.should =~ /Additionally, you could also share your experience working with us/
  end

  it "should create a new survey remark" do
    ticket = create_ticket({ :status => 2 }, @group)
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @user.id})
    note.save_note
    send_while = rand(1..4)
    s_handle = create_survey_handle(ticket, send_while, note)
    rating_type = rand(1..3)
    s_handle.create_survey_result Survey::CUSTOMER_RATINGS[rating_type]
    remark = Faker::Lorem.sentence
    
    post :create, :survey => { :feedback => remark }, 
                  :survey_code => s_handle.id_token, 
                  :rating  => rating_type
    s_result = s_handle.survey_result
    s_remark = SurveyRemark.find(s_result.id)
    s_remark.should be_an_instance_of(SurveyRemark)
    note = ticket.notes.last
    s_remark.note_id.should be_eql(note.id)
    note.body.should be_eql(remark)
  end

  it "should record a survey from the ticket's portal view" do
    ticket = create_ticket({ :status => 2, :requester_id => @user.id }, @group)
    feedback = Faker::Lorem.sentence
    put :create_for_portal, :rating => rand(1..4), 
                            :feedback => feedback, 
                            :ticket_id => ticket.display_id
    ticket.reload
    note = ticket.notes.last
    note.body.should be_eql(feedback)
    survey_remark = note.survey_remark
    survey_remark.should be_an_instance_of(SurveyRemark)
    survey_remark.survey_result.should be_an_instance_of(SurveyResult)
  end
end