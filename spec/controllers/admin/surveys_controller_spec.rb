require 'spec_helper'

describe Admin::SurveysController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
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
    put :update, :id => @account.survey.id , :survey => {  
                                                :link_text => link_text, 
                                                :happy_text => happy_text, 
                                                :neutral_text => neutral_text, 
                                                :unhappy_text => unhappy_text, 
                                                :send_while => 1
                                              }
    survey = Survey.find(:last)
    survey.link_text.should be_eql(link_text)
    survey.happy_text.should be_eql(happy_text)
    survey.neutral_text.should be_eql(neutral_text)
    survey.unhappy_text.should be_eql(unhappy_text)
    survey.send_while.should be_eql(1)
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
end