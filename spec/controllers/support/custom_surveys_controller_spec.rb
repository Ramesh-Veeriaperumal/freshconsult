require 'spec_helper'

describe Support::CustomSurveysController do
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
    @survey = @account.custom_surveys.first
    @survey.update_attributes(send_while: 1)
    survey_question = @survey.survey_questions.new(:name => 'default_survey_question' ,:field_type => :custom_survey_radio , :position => 1, :deleted => 0 ,
                      :label => 'Please tell us what you think of your support experience.' , :column_name => 'cf_int01' ,:default =>1) 
    survey_question.save!
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @user.id})
    note.save_note
    s_handle = CustomSurvey::SurveyHandle.create_handle(ticket, note, false)

    rating_type = rand(100..103)
    s_handle.create_survey_result(CustomSurvey::Survey::CUSTOMER_RATINGS[rating_type])
    get :new, :survey_code => s_handle.id_token, :rating => CustomSurvey::Survey::CUSTOMER_RATINGS[rating_type]
    s_result = CustomSurvey::SurveyHandle.find(s_handle.id).survey_result
    s_result.should be_an_instance_of(CustomSurvey::SurveyResult)
    s_handle.agent_id.should eql note.user_id
  end

  it "should delete a previous survey result and create a new survey handle" do 
    ticket = create_ticket({ :status => 2 }, @group)
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @user.id})
    note.save_note
    s_handle = CustomSurvey::SurveyHandle.create_handle(ticket, note,false)
    
    rating_type = rand(100..103)
    s_handle.create_survey_result(CustomSurvey::Survey::CUSTOMER_RATINGS[rating_type])
    s_handle.update_attributes(:rated => false)
    get :new, :survey_code => s_handle.id_token, :rating => CustomSurvey::Survey::CUSTOMER_RATINGS[rating_type]
    s_result = CustomSurvey::SurveyResult.find(:last)
    s_result.should be_an_instance_of(CustomSurvey::SurveyResult)
    s_handle.agent_id.should eql note.user_id
  end

  it "should create survey remark" do
    ticket = create_ticket({ :status => 2 }, @group)
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @user.id})
    note.save_note
    s_handle = CustomSurvey::SurveyHandle.create_handle(ticket, note,false)
    
    rating_type = rand(100..103)
    s_handle.create_survey_result(CustomSurvey::Survey::CUSTOMER_RATINGS[rating_type])
    s_handle.update_attributes(:rated => false)
    s_result = CustomSurvey::SurveyResult.find(:last)

    params ={}
    params[:survey_result] = s_result.id
    params[:rating] = s_result.rating
    params[:custom_field] = {}
    params[:feedback] = Faker::Lorem.sentence
    s_result.add_feedback(params)
    s_result.survey_remark.should be_an_instance_of(CustomSurvey::SurveyRemark)
    s_result.survey_remark should_not eql nil
  end

  it "should record a survey from the ticket's portal view" do
    ticket = create_ticket({ :status => 2 }, @group)
    feedback = Faker::Lorem.sentence
    note = ticket.notes.build({:note_body_attributes => {:body => Faker::Lorem.sentence}, :user_id => @user.id})
    note.save_note
    s_handle = CustomSurvey::SurveyHandle.create_handle(ticket, note, false)
    rating_type = rand(100..103)
    get :new, :survey_code => s_handle.id_token, :rating => CustomSurvey::Survey::CUSTOMER_RATINGS[rating_type]
    s_handle.should be_an_instance_of(CustomSurvey::SurveyHandle)
  end
end