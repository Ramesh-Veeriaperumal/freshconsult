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

  it "should deactivate customer satisfaction surveys" do
    survey_id = @account.custom_surveys.first.id
    post :deactivate , {id: survey_id}
    @account.custom_surveys.find_by_id(survey_id).active.should eql 0
  end

  it "should activate customer satisfaction surveys" do
    survey_id = @account.custom_surveys.first.id
    post :activate , {id: survey_id}
    @account.custom_surveys.find_by_id(survey_id).active.should eql 1
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
        post :create ,  :survey => fake_survey_data("Survey with 2 choices"),
                        :jsonData => fake_survey_json_data(2)
          active_survey= @account.custom_surveys.where(:title_text => "Survey with 2 choices").first 
          active_survey.id.should_not eql nil
  end

  it "should create a survey with 3 choices" do
        post :create ,  :survey => fake_survey_data("Survey with 3 choices"),
                        :jsonData => fake_survey_json_data(3)
          active_survey= @account.custom_surveys.where(:title_text => "Survey with 3 choices").first 
          active_survey.id.should_not eql nil
  end

  it "should create a survey with 5 choices" do
        post :create ,  :survey => fake_survey_data("Survey with 5 choices"),
                        :jsonData => fake_survey_json_data(5)
          active_survey= @account.custom_surveys.where(:title_text => "Survey with 5 choices").first 
          active_survey.id.should_not eql nil
  end

  it "should create a survey with 7 choices" do
        post :create ,  :survey => fake_survey_data("Survey with 7 choices", true),
                        :jsonData => fake_survey_json_data(7)
          active_survey= @account.custom_surveys.where(:title_text => "Survey with 7 choices").first 
          active_survey.id.should_not eql nil
  end

  it "should update the customer satisfaction survey settings" do
      active_survey = @account.custom_surveys.where(:title_text => "Survey with 7 choices").last
      put :update , {:id => active_survey.id ,
                      :survey => fake_survey_data("Survey with 7 choices edited"),
                      :jsonData => fake_survey_json_data(7)
                    }

      active_survey.reload
      active_survey.title_text.should eql "Survey with 7 choices edited"
      active_survey.send_while.should eql 3
  end

  it "should delete a survey" do
      survey = @account.custom_surveys.where(:title_text => "Survey with 5 choices").first  
      delete :destroy, {:id=>survey.id}

      survey.reload
      survey.should_not be_nil
      survey.deleted.should be true
  end

  def fake_survey_data(name, active=false)
    { 
      "title_text"              =>  name, 
      "thanks_text"             =>  "Thank you for ur feedback", 
      "comments_text"           =>  "Add more details about customer  experience.", 
      "feedback_response_text"  =>  "Thank you. Your feedback has been submitted.", 
      "send_while"              =>  "3", 
      "can_comment"             =>  true, 
      "active"                  =>  active
    }.to_json
  end

  def fake_survey_json_data(num_choices)    
    [
      {"type"=>"survey_radio", "field_type"=>"custom_survey_radio", "label"=>"Hello How are you ?", "id"=>nil, 
        "custom_field_choices_attributes"=> fake_choices(num_choices.to_s), 
      "action"=>"create", "default"=>true, "position"=>1},
      {"type"=>"survey_radio", "field_type"=>"custom_survey_radio", "id"=>nil, "action"=>"create", "default"=>false, 
        "custom_field_choices_attributes"=>[{"value"=>"Strongly Disagree", "face_value"=>-103, "position"=>1, "_destroy"=>0}, {"value"=>"Neutral", "face_value"=>100, "position"=>2, "_destroy"=>0}, {"value"=>"Strongly Agree", "face_value"=>103, "position"=>3, "_destroy"=>0}], 
      "label"=>"Are you satisfied with our customer support experience?", "position"=>2} 
    ].to_json
  end

  def fake_choices(num)
    { 
      "2" => [{"value"=>"Strongly Disagree1", "face_value"=>-103, "position"=>1, "_destroy"=>0}, {"value"=>"Strongly Agree3", "face_value"=>103, "position"=>2, "_destroy"=>0}],
      "3" => [{"value"=>"Strongly Disagree1", "face_value"=>-103, "position"=>1, "_destroy"=>0}, {"value"=>"Neutral2", "face_value"=>100, "position"=>2, "_destroy"=>0}, {"value"=>"Strongly Agree3", "face_value"=>103, "position"=>3, "_destroy"=>0}],
      "5" => [{"value"=>"Strongly Disagree1", "face_value"=>-103, "position"=>1, "_destroy"=>0}, {"value"=>"Some What Disagree", "face_value"=>-102, "position"=>2, "_destroy"=>0}, {"value"=>"Neutral2", "face_value"=>100, "position"=>3, "_destroy"=>0}, {"value"=>"Some What Agree", "face_value"=>102, "position"=>4, "_destroy"=>0}, {"value"=>"Strongly Agree3", "face_value"=>103, "position"=>5, "_destroy"=>0}],
      "7" => [{"value"=>"Strongly Disagree1", "face_value"=>-103, "position"=>1, "_destroy"=>0}, {"value"=>"Some What Disagree", "face_value"=>-102, "position"=>2, "_destroy"=>0}, {"value"=>"Disagree", "face_value"=>-101, "position"=>3, "_destroy"=>0}, {"value"=>"Neutral2", "face_value"=>100, "position"=>4, "_destroy"=>0}, {"value"=>"Agree", "face_value"=>101, "position"=>5, "_destroy"=>0}, {"value"=>"Some What Agree", "face_value"=>102, "position"=>6, "_destroy"=>0}, {"value"=>"Strongly Agree3", "face_value"=>103, "position"=>7, "_destroy"=>0}]      
    }[num]
  end
end
