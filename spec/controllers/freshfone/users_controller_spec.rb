require 'spec_helper'

describe Freshfone::UsersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @request.host = @account.full_domain
    log_in(@agent)
    
    create_test_freshfone_account
    create_freshfone_user
  end

  after(:each) do
    @account.freshfone_users.find(assigns[:freshfone_user]).destroy
  end

  it 'should reset presence to incoming preference' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    @freshfone_user.update_attributes(:incoming_preference => 1)
    post :presence
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_online
    json.should be_eql({:update_status => true})
  end

  it 'should validate and set presence on request from nodejs' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    @request.env["HTTP_X_FRESHFONE_SESSION"] = 
          Digest::SHA512.hexdigest("#{FreshfoneConfig['secret_key']}::#{@agent.id}")
    post :node_presence, {:status => 1, :node_user => @agent.id}
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_online
    json.should be_eql({:update_status => true})
  end

  it 'should not update presence when user available on mobile' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    @request.env["HTTP_X_FRESHFONE_SESSION"] = 
          Digest::SHA512.hexdigest("#{FreshfoneConfig['secret_key']}::#{@agent.id}")
    @freshfone_user.update_attributes(:available_on_phone => 1)
    post :node_presence, { :status => 1, :node_user => @agent.id }
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_offline
    json.should be_eql({:update_status => false})
  end

  it 'should reset presence on node reconnect when user is not busy' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    @freshfone_user.update_attributes(:incoming_preference => 1)
    post :reset_presence_on_reconnect
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_online
    json.should be_eql({:status => true})
  end

  it 'should not reset presence on node reconnect when user is busy' do 
    @request.env["HTTP_ACCEPT"] = "application/json"
    @freshfone_user.update_attributes(:incoming_preference => 1, :presence => 2)
    post :reset_presence_on_reconnect
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_busy
    json.should be_eql({:status => false})
  end

  it 'should update available on phone option' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    post :availability_on_phone, {:available_on_phone => true}
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_available_on_phone
  end

  it 'should get a new capa token on presence change' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    controller.stubs(:bridge_queued_call)
    post :refresh_token, {:status => 1}
    json.keys.should be_eql([:update_status, :token, :client, :expire])
  end

  it 'should not get a new capa token on incorrect freshfone user' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    Freshfone::User.any_instance.stubs(:save).returns(false)
    controller.stubs(:bridge_queued_call)
    post :refresh_token, {:status => 1}
    json.should be_eql({:update_status => false})
  end

  it 'should set user presence as busy' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    post :in_call, {:outgoing => "false"}
    json.should be_eql({:update_status => true, :call_sid => nil})
  end

  it 'should set user presence as busy and return a call SID for outgoing call' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    create_freshfone_call
    @freshfone_call.update_attributes(:call_status => Freshfone::Call::CALL_STATUS_HASH[:default])
    post :in_call, {:outgoing => "true"}
    json.should be_eql({:update_status => true, :call_sid => "CA2db76c748cb6f081853f80dace462a04"})
  end

  it 'should build a new freshfone user if current user is not available' do
    @request.env["HTTP_ACCEPT"] = "application/json"
    @freshfone_user.destroy
    post :presence
    @freshfone_user = @agent.freshfone_user
    @freshfone_user.should be_an_instance_of(Freshfone::User)
  end


end