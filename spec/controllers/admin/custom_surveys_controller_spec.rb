require 'spec_helper'

describe Admin::CustomSurveysController do

  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
    @link_text = Faker::Lorem.sentence
  end

  it "should display the custom satisfaction survey settings page" do
    get :index
    response.body.should =~ /Surveys/
  end

  it "should disable customer satisfaction surveys" do
    post :disable , {id: @account.custom_surveys.first.id}
    @account.features.find_by_type("SurveyLinksFeature").should eql nil
  end

  it "should enable customer satisfaction surveys" do
    post :enable , {id: @account.custom_surveys.first.id}
    @account.features.find_by_type("SurveyLinksFeature").should be_an_instance_of(SurveyLinksFeature)
  end

  it "should create a new ticket and send notification emails with a survey" do
    Delayed::Job.destroy_all
    test_ticket = create_ticket
    notification = @account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
    notification.update_attributes(:requester_notification => false)
    create_note({:source => 0,
                 :ticket_id => test_ticket.id,
                 :body => Faker::Lorem.paragraph,
                 :user_id => @agent.id,
                 :private => false, 
                 :incoming => false})
    10.times do Delayed::Job.reserve_and_run_one_job end
    Delayed::Job.count.should eql 0
  end

  it "should create a survey with 2 choices" do
        post :create ,  :survey => {"default" => false,"choices" => [["Strongly Agree", 103],["Strongly Disagree", -103]],
                        "title_text" => "dummy","link_text" => " How would you rate your overall satisfaction for the resolution provided by the agent?",
                        "choice" => "2","send_while" => "1","thanks_text" => "Thank you for your valuable feedback. Please help us to serve you better by answering few more questions..",
                        "feedback_response_text" => "","can_comment" => true,"active" => false}.to_json,
                        :jsonData => [{"name" =>  "Q1", "type" => "survey_radio", "field_type"=> "custom_survey_radio", 
                        "label" => "Are you satisfied with our customer support experience?", 
                        "choices" => [["Strongly Agree", 103, 1], ["Strongly Disagree", -103, 2]], "action" => "create"}].to_json   
          active_survey= @account.custom_surveys.find(:all , :conditions => {:title_text => "dummy"}).first 
          active_survey.id.should_not eql nil
  end
  it "should create a survey with 3 choices" do
    post :create ,  :survey => {"default" => false,"choices" => [["Strongly Agree", 103],["Neutral",100],["Strongly Disagree", -103]],
                        "title_text" => "dummy_choices3","link_text" => " How would you rate your overall satisfaction for the resolution provided by the agent?",
                        "choice" => "3","send_while" => "1","thanks_text" => "Thank you for your valuable feedback. Please help us to serve you better by answering few more questions..",
                        "feedback_response_text" => "","can_comment" => true,"active" => false}.to_json,
                        :jsonData => [{"name" =>  "Q1", "type" => "survey_radio", "field_type"=> "custom_survey_radio", 
                        "label" => "Are you satisfied with our customer support experience?", 
                        "choices" => [["Strongly Agree", 103, 1],["Neutral",100,2],["Strongly Disagree", -103, 3]], "action" => "create"}].to_json   
    active_survey= @account.custom_surveys.find(:all , :conditions => {:title_text => "dummy_choices3"}).first 
    active_survey.id.should_not eql nil
  end


it "should create a survey with 5 choices" do
    post :create ,  :survey => {"default" => false, "choices" => [["Strongly Agree", 103],["Some What Agree",102],["Neutral",100],["Some What Disagree",-102],["Strongly Disagree", -103]],
                        "title_text" => "dummy_choices5","link_text" => " How would you rate your overall satisfaction for the resolution provided by the agent?",
                        "choice" => "5","send_while" => "1","thanks_text" => "Thank you for your valuable feedback. Please help us to serve you better by answering few more questions..",
                        "feedback_response_text" => "","can_comment" => true,"active" => false}.to_json,
                        :jsonData => [{"name" =>  "Q1", "type" => "survey_radio", "field_type"=> "custom_survey_radio", 
                        "label" => "Are you satisfied with our customer support experience?", 
                        "choices" => [["Strongly Agree", 103,1],["Some What Agree",102,2],["Neutral",100,3],["Some What Disagree",-102,4],["Strongly Disagree", -103,5]], "action" => "create"}].to_json   
    active_survey= @account.custom_surveys.find(:all , :conditions => {:title_text => "dummy_choices5"}).first 
    active_survey.id.should_not eql nil
  end

  it "should create a survey with 7 choices" do
    post :create ,  :survey => {"default" => false,"choices" => [["Strongly Agree", 103],["Some What Agree",102],["Agree",101],["Neutral",100],["Disagree",-101],
                        ["Some What Disagree",-102],["Strongly Disagree", -103]],
                        "title_text" => "dummy_choices7","link_text" => " How would you rate your overall satisfaction for the resolution provided by the agent?",
                        "choice" => "7","send_while" => "1","thanks_text" => "Thank you for your valuable feedback. Please help us to serve you better by answering few more questions..",
                        "feedback_response_text" => "","can_comment" => true,"active" => false}.to_json,
                        :jsonData => [{"name" =>  "Q1", "type" => "survey_radio", "field_type"=> "custom_survey_radio", 
                        "label" => "Are you satisfied with our customer support experience?", 
                        "choices" => [["Strongly Agree", 103,1],["Some What Agree",102,2],["Agree",101,3],
                                      ["Neutral",100,4],["Disagree",-101,5],["Some What Disagree",-102,6],
                                      ["Strongly Disagree", -103,7]], "action" => "create"}].to_json   
    active_survey= @account.custom_surveys.find(:all , :conditions => {:title_text => "dummy_choices7"}).first 
    active_survey.update_attributes(:default => false)
    active_survey.id.should_not eql nil
  end

  it "should update the customer satisfaction survey settings" do
      active_survey= @account.custom_surveys.find(:all , :conditions => {:active => true}).first
      choice = 2
      survey_result = active_survey.survey_results.last
      unless survey_result.blank?
      put :update , {:id => active_survey.id ,
                      :survey => {"default" => false,
                                  "link_text" => "How would you rate your overall satisfaction for the resolution provided by the agent?",
                                  "title_text" => "Default Survey",
                                  "send_while" => 2,
                                  "active" => true,
                                  "thanks_text" =>  "Thank you for your valuable feedback.",
                                  "feedback_response_text"=> "dhankie",
                                  "can_comment" => true,
                                  "choices" => [["Strongly Agree Updated", 103],["Strongly Disagree Updated", -103]] ,    
                                  "choice" => choice}.to_json,
                      :jsonData =>[{"name" => "Q1", "type" => "survey_radio" , 
                                    "field_type" => "custom_survey_radio",
                                    "label" => "question1" , "id" => nil , 
                                    "action" => "update",
                                    "choices" => [["Strongly Agree update", 103, 1], ["Strongly Disagree update", -103, 2]]}].to_json }
      end
      survey = @account.custom_surveys.find(active_survey.id)
      survey.title_text.should eql "Default Survey"
      survey.send_while.should eql 2
  end

  it "should delete a survey" do
      survey= @account.custom_surveys.find(:all , :conditions => {:title_text => "dummy_choices7"}).first  
      delete :destroy, {:id=>survey.id}
      @account.surveys.find_by_id(survey.id).should be_nil
  end
end
