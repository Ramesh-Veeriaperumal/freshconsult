require 'spec_helper'

describe Freshfone::OpsNotificationController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
  end

  it 'should render the twiml with notification message' do
    path = 'freshfone/ops_notification/voice_notification'
    query_params = '?message=test'
    params = {"message" => "test"}
    set_twilio_signature(path+query_params, params.except("message"), true)
    post :voice_notification, params
    xml.should be_eql({:Response=>{:Say=>"test"}})
  end

  it 'should render empty twiml on status call' do
    set_twilio_signature('freshfone/ops_notification/status', {}, true)
    post :status
    xml.should be_eql({:Response=>nil})
  end
end