require 'spec_helper'

describe Admin::SurveysController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should not update the survey settings with invalid params" do
    send_while = rand(1..4)
    put :update, :id => "update", :survey => {  
                                                :link_text => nil, 
                                                :happy_text => nil, 
                                                :neutral_text => nil, 
                                                :unhappy_text => nil, 
                                                :send_while => send_while
                                              }
    survey = @account.survey
    survey.link_text.should_not be_nil
    survey.happy_text.should_not be_nil
    survey.neutral_text.should_not be_nil
    survey.unhappy_text.should_not be_nil
  end
end