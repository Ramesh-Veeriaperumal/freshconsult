require 'spec_helper'

describe FreshfoneController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @account.update_attributes(:full_domain => "http://play.ngrok.com")
    create_test_freshfone_account
    @request.host = @account.full_domain
  end

  #Spec for Freshfone base controller
  it 'should custom-validate request from Twilio and allow call' do
    set_twilio_signature('freshfone/voice', incoming_params)
    post :voice, incoming_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

  it 'should fail on extremely low freshfone credit' do
    set_twilio_signature('freshfone/voice', incoming_params)
    @account.freshfone_credit.update_attributes(:available_credit => 0.1)
    post :voice, incoming_params
    xml.should be_eql({:Response=>{:Reject=>nil}})
  end

  it 'should fail on missing freshfone feature' do
    set_twilio_signature('freshfone/voice', incoming_params)
    @account.features.freshfone.destroy
    post :voice
    response.should render_template "/errors/non_covered_feature"
  end

  it 'should redirect to login when non-twilio-aware methods are called by not logged in users' do
    get :dashboard_stats
    response.should be_redirect
    response.should redirect_to('support/login')
  end
  #End spec for freshfone base controller


  #Spec for actual freshfone_controller
  it 'should render valid twiml on ivr_flow' do  
    set_twilio_signature('freshfone/ivr_flow?menu_id=0', ivr_flow_params.except("menu_id"))
    post :ivr_flow, ivr_flow_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

  it 'should render valid twiml on voice_fallback' do  
    set_twilio_signature('freshfone/voice_fallback', fallback_params)
    post :voice_fallback, fallback_params
    xml.should have_key(:Response)
  end

  it 'should render valid js on dashboard_stats' do
    log_in(@agent)
    get :dashboard_stats
    response.should render_template("freshfone/dashboard_stats.rjs")
  end

  it 'should render valid json on credit_balance' do
    log_in(@agent) 
    get :credit_balance
    json.should have_key :credit_balance
  end

  it 'should apply indian number fix for incorrect caller id' do
    modified_params = incoming_params
    modified_params["From"] = "+166174802401"
    set_twilio_signature('freshfone/voice', modified_params)
    post :voice, modified_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

end