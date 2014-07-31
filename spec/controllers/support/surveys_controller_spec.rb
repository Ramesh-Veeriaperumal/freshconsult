require 'spec_helper'

describe Support::SurveysController do
  # integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group = create_group(@account, {:name => "survey"})
  end

  before(:each) do
    login_admin
  end

  it "should create a new survey handle" do 
    ticket = create_ticket({ :status => 2 }, @group)
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}})
    note.save_note
    send_while = rand(1..4)
    s_handle = create_survey_handle(ticket, send_while, note)
    rating_type = rand(1..3)

    get :new, :survey_code => s_handle.id_token, :rating => Survey::CUSTOMER_RATINGS[rating_type]
    s_result = SurveyHandle.find(s_handle.id).survey_result
    s_result.should be_an_instance_of(SurveyResult)
    s_result.rating.should be_eql(rating_type)
  end

  it "should create a new survey remark" do
    ticket = create_ticket({ :status => 2 }, @group)
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}})
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
    s_remark = SurveyRemark.find_by_survey_result_id(s_result.id)
    s_remark.should be_an_instance_of(SurveyRemark)
    note = ticket.notes.last
    s_remark.note_id.should be_eql(note.id)
    note.body.should be_eql(remark)
  end

  it "should record a survey from the ticket's portal view" do
    ticket = create_ticket({ :status => 2 }, @group)
    feedback = Faker::Lorem.sentence
    put :create_for_portal, :rating => rand(1..4), 
                            :feedback => feedback, 
                            :ticket_id => ticket.display_id
    note = ticket.notes.last
    note.body.should be_eql(feedback)
    survey_remark = note.survey_remark
    survey_remark.should be_an_instance_of(SurveyRemark)
    survey_remark.survey_result.should be_an_instance_of(SurveyResult)
  end
end