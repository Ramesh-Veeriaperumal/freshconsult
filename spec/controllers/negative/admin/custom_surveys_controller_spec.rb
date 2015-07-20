require 'spec_helper'

describe Admin::CustomSurveysController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should not create survey with invalid params" do
    expect{
       post :create ,  :survey => {"default"=>false,"choices" => '[["Strongly Agree", 103],["Strongly Disagree", -103]]',
                        "title_text" => nil,"link_text" => " How would you rate your overall satisfaction for the resolution provided by the agent?",
                        "choice" => "2","send_while" => "1","thanks_text" => "Thank you for your valuable feedback. Please help us to serve you better by answering few more questions..",
                        "feedback_response_text" => "","can_comment" => true,"active" => false}.to_json,
                        :jsonData => [{"name" =>  "Q1", "type" => "survey_radio", "id" => nil,"field_type"=> "custom_survey_radio", 
                        "label" => "Are you satisfied with our customer support experience?", 
                        "choices" => [["Strongly Agree", 103, 1], ["Strongly Disagree", -103, 2]], "action" => "create"}].to_json   
    }.to raise_error
    survey = @account.custom_surveys.first          
    survey.should_not be_nil
  end

  it "should not update the survey settings with invalid params" do
    send_while = rand(100..103)
    expect{
      put :update , {:id => nil ,
                      :survey => {"default" => false,"link_text" => nil,
                                  "title_text" => "dummy",
                                  "send_while" => 2,
                                  "thanks_text" =>  "Thank you for your valuable feedback.",
                                  "can_comment" => true,
                                  "choices" => '[["Strongly Agree Updated", 103],["Strongly Disagree Updated", -103]]' ,    
                                  "choice" => 2}.to_json,
                      :jsonData =>[{"name" => "Q1", "type" => "survey_radio" , 
                                    "field_type" => "custom_survey_radio",
                                    "label" => "question1" , "id" => nil , 
                                    "action" => "update",
                                    "choices" => [["Strongly Agree update", 103, 1], ["Strongly Disagree update", -103, 2]]}].to_json }
    }.to raise_error                                        
    survey = @account.custom_surveys.first          
    survey.should_not be_nil
  end

  it "should not delete default survey" do
    survey = @account.custom_surveys.first
    delete :destroy, {:id=>survey.id}
    survey.id.should_not be_nil
  end

   it "should not delete active survey" do
    survey = @account.custom_surveys.first
    delete :destroy, {:id=>survey.id}
    survey.id.should_not be_nil
  end
end