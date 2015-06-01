require 'spec_helper'
load 'spec/support/freshfone_transfer_spec_helper.rb'
RSpec.configure do |c|
  c.include FreshfoneTransferSpecHelper
end

RSpec.describe Freshfone::CallTransferController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
  end

  it 'should fail on invalid call transfer by sending a completed call sid' do
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    post :initiate, initiate_params
    json.should be_eql({:call => "failure"})
  end

  it 'should render valid transfer twiml on correct inputs' do
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    Twilio::REST::Call.any_instance.stubs(:update).returns(true)
    post :initiate, initiate_params
    json.should be_eql({:call => "success"})
  end

  it 'should return all available agents for transfer' do
    log_in(@agent)
    create_dummy_freshfone_users
    get :available_agents
    assigns[:freshfone_users].should_not be_empty
  end

  it 'should return all available agents excluding the existing users' do
    log_in(@agent)
    create_dummy_freshfone_users
    dummy = @dummy_users.first.id
    get :available_agents, {:existing_users_id => [ dummy.to_s ]}
    assigns[:freshfone_users].collect { |u| u[:id] }.should_not include(dummy)
  end

  it 'should render incoming transfer twiml' do
    create_dummy_freshfone_users(1)
    query_params = "id=#{@dummy_users.first.id}&source_agent=#{@agent.id}"
    set_twilio_signature("freshfone/call_transfer/transfer_incoming_call?#{query_params}", 
      incoming_call_transfer_params)
    post :transfer_incoming_call, 
      incoming_call_transfer_params.merge({ :id => @dummy_users.first.id, 
                                            :source_agent => @agent.id })
    xml[:Response][:Dial][:Client].should be_eql(@dummy_users.first.id.to_s)
  end

  it 'should render outgoing transfer twiml' do
    create_dummy_freshfone_users(1)
    query_params = "id=#{@dummy_users.first.id}&source_agent=#{@agent.id}"
    set_twilio_signature("freshfone/call_transfer/transfer_outgoing_call?#{query_params}", 
      outgoing_call_transfer_params)
    post :transfer_outgoing_call, 
      outgoing_call_transfer_params.merge({ :id => @dummy_users.first.id, 
                                            :source_agent => @agent.id })
    xml[:Response][:Dial][:Client].should be_eql(@dummy_users.first.id.to_s)
  end

end