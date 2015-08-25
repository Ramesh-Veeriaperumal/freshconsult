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
    @account.features.freshfone_conference.delete if @account.features?(:freshfone_conference)
    @account.reload
    @account.freshfone_callers.delete_all
    @request.host = @account.full_domain
  end

  it 'should fail on invalid call transfer by sending a completed call sid' do
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    stub_twilio_call_with_parent(false)
    post :initiate, initiate_params
    json.should be_eql({:call => "failure"})
    Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should render valid transfer twiml on correct inputs' do
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    stub_twilio_call_with_parent
    post :initiate, initiate_params
    json.should be_eql({:call => "success"})
    Twilio::REST::Calls.any_instance.unstub(:get)
  end


  it 'should render valid transfer twiml on correct inputs' do
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    @account.features.freshfone_conference.create unless @account.features?(:freshfone_conference)
    stub_twilio_call_with_parent
    post :initiate, initiate_params
    json.should be_eql({:call => "success"})
    Twilio::REST::Calls.any_instance.unstub(:get)
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

  it 'should render valid external incoming transfer twiml on correct inputs' do
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    Twilio::REST::Call.any_instance.stubs(:update).returns(true)
    outgoing = "false"
    stub_twilio_call_with_parent
    post :initiate, initiate_external_params(outgoing)
    json.should be_eql({:call => "success"})
    Twilio::REST::Calls.any_instance.unstub(:get)
    Twilio::REST::Call.any_instance.unstub(:update)
  end

  it 'should return empty for available external numbers for transfer' do
    log_in(@agent)
    get :available_external_numbers
    expect(assigns[:external_numbers]).to be_empty
  end

  it 'should return all available external numbers for transfer' do
    log_in(@agent)
    create_external_transfered_call
    get :available_external_numbers
    expect(assigns[:external_numbers]).not_to be_empty
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

  
  it "should render transfer incoming to group twiml" do
    @test_group = create_group(@account, {:name => "Spec Testing Grp Helper"})
    role_id = @account.roles.find_by_name("Account Administrator").id
    agent = add_agent(@account,{ :name => Faker::Name.name,
                        :email => Faker::Internet.email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => 1,
                        :role_ids => ["#{role_id}"],
                        :group_id => @test_group.id})
    create_freshfone_user(1, agent)
    create_freshfone_call('CA2db76c748cb6f081853f80dace462a04')
    query_params = "target=#{@test_group.id}&group_id=@test_group.id&source_agent=#{@agent.id}"
    set_twilio_signature("/freshfone/call_transfer/transfer_incoming_to_group?#{query_params}", 
      incoming_call_transfer_params)
    post :transfer_incoming_to_group, incoming_call_transfer_params.merge({ :id=> @test_group.id ,:group_id=> @test_group.id, :source_agent => @agent.id })
    xml[:Response][:Dial][:Client].should be_eql(agent.id.to_s)
  end

  it "should render transfer outgoing to group twiml" do
    @test_group = create_group(@account, {:name => "Spec Testing Grp Helper1"})
    role_id = @account.roles.find_by_name("Account Administrator").id
    agent = add_agent(@account,{ :name => Faker::Name.name,
                        :email => Faker::Internet.email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => 1,
                        :role_ids => ["#{role_id}"],
                        :group_id => @test_group.id})
    create_freshfone_user(1, agent)
    create_freshfone_call('CA2db76c748cb6f081853f80dace462a04',Freshfone::Call::CALL_TYPE_HASH[:outgoing])
    query_params = "target=#{@test_group.id}&group_id=@test_group.id&source_agent=#{@agent.id}"
    set_twilio_signature("/freshfone/call_transfer/transfer_outgoing_to_group?#{query_params}", 
      outgoing_call_transfer_params)
    post :transfer_outgoing_to_group, outgoing_call_transfer_params.merge({ :id=> @test_group.id ,"source_agent"=> @agent.id, :group_id=>@test_group.id })
    xml[:Response][:Dial][:Client].should be_eql(agent.id.to_s)
  end

  it 'should render incoming transfer twiml' do
    query_params = "number=%2B919876543210&source_agent=#{@agent.id}"
    set_twilio_signature("/freshfone/call_transfer/transfer_incoming_to_external?#{query_params}", 
      incoming_external_transfer_params)
    post :transfer_incoming_to_external, 
      incoming_external_transfer_params.merge({ "number"=>"+919876543210", "source_agent"=> @agent.id})
    expect(xml[:Response][:Dial][:Number]).to be_eql("+919876543210")
  end

  it 'should render outgoing external transfer twiml' do
    query_params = "number=919876543210&source_agent=#{@agent.id}"
    set_twilio_signature("/freshfone/call_transfer/transfer_outgoing_to_external?#{query_params}", outgoing_external_transfer_params)
    post :transfer_outgoing_to_external, outgoing_external_transfer_params.merge({ "number"=>"+919876543210", "source_agent"=> @agent.id})
    expect(response.status).to eq(200)
    expect(xml[:Response][:Dial][:Number]).to be_eql("+919876543210")
  end
end