require 'spec_helper'

describe Admin::SurveysController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@user)
  end

  it "should display the custom satisfaction survey settings page" do
    get :index
    response.body.should =~ /Customer Satisfaction Settings/
  end

  it "should disable customer satisfaction surveys" do
    post :disable
    @account.features.find_by_type("SurveyLinksFeature").should be_nil
  end

  it "should enable customer satisfaction surveys" do
    post :enable
    @account.features.find_by_type("SurveyLinksFeature").should be_an_instance_of(SurveyLinksFeature)
  end

  it "should update the customer satisfaction survey settings" do
    link_text = Faker::Lorem.sentence
    happy_text = Faker::Lorem.sentence
    neutral_text = Faker::Lorem.sentence
    unhappy_text = Faker::Lorem.sentence
    send_while = rand(1..4)
    put :update, :id => "update", :survey => {  
                                                :link_text => link_text, 
                                                :happy_text => happy_text, 
                                                :neutral_text => neutral_text, 
                                                :unhappy_text => unhappy_text, 
                                                :send_while => send_while
                                              }
    survey = @account.survey
    survey.link_text.should be_eql(link_text)
    survey.happy_text.should be_eql(happy_text)
    survey.neutral_text.should be_eql(neutral_text)
    survey.unhappy_text.should be_eql(unhappy_text)
    survey.send_while.should be_eql(send_while)
  end
end