require 'spec_helper'

RSpec.configure do |c|
  c.include ConferenceTransferSpecHelper
end

RSpec.describe Freshfone::HoldController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account.freshfone_calls.destroy_all
  end

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    @account.freshfone_calls.destroy_all
    @account.freshfone_callers.delete_all
    create_freshfone_user
    log_in @agent
    create_freshfone_conf_call('CONFCALL')
  end

  it 'should make the agent`s sound to muted state while the agent puts the call on hold' do
  	@freshfone_call.update_attributes!({ :call_status => Freshfone::Call::CALL_STATUS_HASH[:'in-progress'] })
  	call_mock = mock
  	call_mock.stubs(:update)
  	Twilio::REST::Calls.any_instance.stubs(:get).returns(call_mock)
  	get :add, { :CallSid => @freshfone_call.call_sid }
  	@freshfone_call.reload
  	expect(json).to be_truthy
  	expect(json[:status]).to be_truthy
  	expect(json[:status]).to eq("hold_initiated")
  	expect(@freshfone_call.onhold?).to be true
  	Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should return error if an agent tries to put the call on hold which is not in progress' do
  	get :add, { :CallSid => @freshfone_call.call_sid }
  	expect(json).to be_truthy
  	expect(json[:status]).to eq("error")
  end

  it 'should make the agent disconnect from the call when there is an exception rises while adding to hold' do

  	@freshfone_call.update_attributes!({ :call_status => Freshfone::Call::CALL_STATUS_HASH[:'in-progress'] })
  	Freshfone::Call.any_instance.stubs(:onhold!).raises(StandardError.new("Unknown Error"))
  	get :add, { :CallSid => @freshfone_call.call_sid }
  	expect(json).to be_truthy
  	expect(json[:status]).to eq("error")
  	Freshfone::Call.any_instance.unstub(:onhold!)
  end

  it 'should initiate the hold without any exceptions' do
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    create_freshfone_conf_call('CONFCALL',Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
    set_twilio_signature("freshfone/hold/initiate?call=#{@freshfone_call.id}&hold_queue=hold_CAeab765499b16de80d428196f8c59ef28&transfer=true&source=@agent.user_id&target=transfer_agent.id&transfer_type=normal&group_transfer=false", hold_initiate_params.except(:call,:hold_queue,:transfer,:source,:target,:transfer_type,:group_transfer))
    post :initiate, hold_initiate_params
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response][:Enqueue]).to be_truthy
  end

  it 'should disconnect agent and return error on exception' do
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    create_freshfone_conf_call('CONFCALL',Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
    Freshfone::Telephony.any_instance.stubs(:hold_enqueue).raises(StandardError.new('Unknown Error'))
    Freshfone::Call.any_instance.stubs(:disconnect_agent)
    set_twilio_signature("freshfone/hold/initiate?call=#{@freshfone_call.id}&hold_queue=hold_CAeab765499b16de80d428196f8c59ef28&transfer=true&source=@agent.user_id&target=transfer_agent.id&transfer_type=normal&group_transfer=false", hold_initiate_params.except(:call,:hold_queue,:transfer,:source,:target,:transfer_type,:group_transfer))
    post :initiate, hold_initiate_params
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_blank
    Freshfone::Call.any_instance.unstub(:disconnect_agent)
  end

  it 'should make the agent muted while he is on hold on transferring' do
    agent1 = add_test_agent(@account)
    create_freshfone_user(1, agent1)
    create_freshfone_user(Freshfone::User::PRESENCE[:online], agent1)
    conference = mock
    Twilio::REST::Conferences.any_instance.stubs(:get).returns(conference)
    Freshfone::Providers::Twilio.any_instance.stubs(:mute_participants)
    create_freshfone_conf_call('CONFCALL')
    @freshfone_call.update_attributes!({ :conference_sid => "ConSid" })
    set_twilio_signature("freshfone/hold/wait?call=#{@freshfone_call.id}&transfer=true&source=#{@agent.id}&target=#{agent1.id}&transfer_type=normal", hold_wait_params.except(:call,:transfer,:source,:target,:transfer_type))
    post :wait, hold_wait_params.merge!({"call" => @freshfone_call.id, "transfer" =>"true", "source" => @agent.id, "target" => agent1.id, "transfer_type" => "normal"})
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response][:Play]).to be_truthy
    Freshfone::Providers::Twilio.any_instance.unstub(:mute_participants)
    Twilio::REST::Conferences.any_instance.unstub(:get)
  end

  it 'should make the agent muted while he is on hold on transferring a second level transfer' do
    @account.freshfone_calls.destroy_all
    agent1 = add_test_agent(@account)
    create_freshfone_user(1, agent1)
    create_freshfone_user(Freshfone::User::PRESENCE[:online], agent1)
    conference = mock
    Twilio::REST::Conferences.any_instance.stubs(:get).returns(conference)
    Freshfone::Providers::Twilio.any_instance.stubs(:mute_participants)
    create_freshfone_conf_call('CONFCALL')
    @freshfone_call.update_attributes!({ :conference_sid => "ConSid" })
    child_call = create_conf_child_call('CONF_CHILD',@freshfone_call, agent1)
    child_call2 = create_conf_child_call('CONF_CHILD2',@freshfone_call, @agent)
    create_freshfone_conf_call_meta(child_call, [{:id=>agent1.id,:ff_user_id => agent1.id,:name=>agent1.name,:device_type=>:browser,:call_sid =>'CAeab765499b16de80d428196f8c59ef28'}])
    set_twilio_signature("freshfone/hold/wait?call=#{@freshfone_call.id}&transfer=true&source=#{@agent.id}&target=#{agent1.id}&transfer_type=normal", hold_wait_params.except(:call,:transfer,:source,:target,:transfer_type))
    post :wait, hold_wait_params.merge!({"call" => @freshfone_call.id, "transfer" =>"true", "source" => @agent.id, "target" => agent1.id, "transfer_type" => "normal"})
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response][:Play]).to be_truthy
    Freshfone::Providers::Twilio.any_instance.unstub(:mute_participants)
    Twilio::REST::Conferences.any_instance.unstub(:get)
  end


  it 'should make the agent muted while he is on hold on transferring to a group' do
    @test_group = create_group(@account, {:name => "Spec Testing Grp Helper"})
    role_id = @account.roles.find_by_name("Account Administrator").id
    agent1 = add_agent(@account,{ :name => Faker::Name.name,
                        :email => Faker::Internet.email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => 1,
                        :role_ids => ["#{role_id}"],
                        :group_id => @test_group.id})
    create_freshfone_user(1, agent1)
    create_freshfone_user(Freshfone::User::PRESENCE[:online], agent1)
    conference = mock
    Twilio::REST::Conferences.any_instance.stubs(:get).returns(conference)
    Freshfone::Providers::Twilio.any_instance.stubs(:mute_participants)
    create_freshfone_conf_call('CONFCALL')
    @freshfone_call.update_attributes!({ :conference_sid => "ConSid" })
    set_twilio_signature("freshfone/hold/wait?call=#{@freshfone_call.id}&transfer=true&source=@agent.user_id&target=@test_group.id&transfer_type=normal&group_transfer=true", hold_wait_params.except(:call,:transfer,:source,:target,:transfer_type,:group_transfer))
    post :wait, hold_wait_params.merge!({"call" => @freshfone_call.id, "transfer" =>"true", "source" => @agent.id, "target" => @test_group.id, "transfer_type" => "normal", "group_transfer" => "true"})
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response][:Play]).to be_truthy
    Freshfone::Providers::Twilio.any_instance.unstub(:mute_participants)
    Twilio::REST::Conferences.any_instance.unstub(:get)
  end

  it 'should make the agent muted while he is on hold on transferring to an external number' do
    @test_group = create_group(@account, {:name => "Spec Testing Grp Helper"})
    role_id = @account.roles.find_by_name("Account Administrator").id
    conference = mock
    Twilio::REST::Conferences.any_instance.stubs(:get).returns(conference)
    Freshfone::Providers::Twilio.any_instance.stubs(:mute_participants)
    create_freshfone_conf_call('CONFCALL')
    @freshfone_call.update_attributes!({ :conference_sid => "ConSid" })
    set_twilio_signature("freshfone/hold/wait?call=#{@freshfone_call.id}&transfer=true&source=@agent.user_id&target=91987654321&transfer_type=normal&group_transfer=false&external_transfer=true", hold_wait_params.except(:call,:transfer,:source,:target,:transfer_type,:group_transfer))
    post :wait, hold_wait_params.merge!({"call" => @freshfone_call.id, "transfer" =>"true", "source" => @agent.id, "target" => "91987654321", "external_transfer"=>"true","transfer_type" => "normal", "group_transfer" => "false"})
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response][:Play]).to be_truthy
    Freshfone::Providers::Twilio.any_instance.unstub(:mute_participants)
    Twilio::REST::Conferences.any_instance.unstub(:get)
  end

  it 'should disconnect the agent on exception(no current_call) while trying to mute the agent' do
    agent1 = add_test_agent(@account)
    create_freshfone_user(Freshfone::User::PRESENCE[:online], agent1)
    create_freshfone_conf_call('CONFCALL',Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
    Freshfone::Call.any_instance.stubs(:disconnect_agent)
    Freshfone::Telephony.any_instance.stubs(:mute_participants)
    Freshfone::Notifier.any_instance.stubs(:notify_call_hold).raises(StandardError.new('Unknown Error'))
    set_twilio_signature("freshfone/hold/wait?call=0&transfer=true&source=@agent.user_id&target=agent1.id&transfer_type=normal&group_transfer=false", hold_wait_params.except(:call,:transfer,:source,:target,:transfer_type,:group_transfer))
    post :wait, hold_wait_params
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_blank
    Freshfone::Call.any_instance.unstub(:disconnect_agent)
    Freshfone::Telephony.any_instance.unstub(:mute_participants)
  end

  it 'should remove the agent from the hold queue while he pressed the unhold button' do
    @freshfone_call.update_attributes!({ :hold_queue => "HoldQ", :conference_sid => "ConSid", 
      :call_status => Freshfone::Call::CALL_STATUS_HASH[:'on-hold'] })
    queues = mock
    members = mock
    member = mock
    member.stubs(:dequeue)
    members.stubs(:get).returns(member)
    queues.stubs(:members).returns(members)
    Twilio::REST::Queues.any_instance.stubs(:get).returns(queues)
    get :remove, { :CallSid => @freshfone_call.call_sid }
    expect(json).to be_truthy
    expect(json[:status]).to be_truthy
    expect(json[:status]).to eq("unhold_initiated")
    Twilio::REST::Queues.any_instance.unstub(:get)
  end

  it 'should return error json if we try to remove the agentfrom queue while he pressed the unhold button if the cal is not in hold.' do
    @freshfone_call.update_attributes!({ :hold_queue => "HoldQ", :conference_sid => "ConSid", 
      :call_status => Freshfone::Call::CALL_STATUS_HASH[:'in-progress'] })
    get :remove, { :CallSid => @freshfone_call.call_sid }
    expect(json).to eql({:status => "error"})
  end
  
  it 'should unhold the agent and make the call`s status as in-progress' do
    @account.freshfone_calls.destroy_all
    create_freshfone_conf_call('CONFCALL')
    @freshfone_call.update_attributes!({ :conference_sid => 'ConSid' })
    conference = mock
    Twilio::REST::Conferences.any_instance.stubs(:get).returns(conference)
    Freshfone::Providers::Twilio.any_instance.stubs(:unmute_participants)
    child_call = create_conf_child_call('CONF_CHILD')
    set_twilio_signature("/freshfone/hold/unhold?call=#{@freshfone_call.id}", { :CallSid => @freshfone_call.call_sid })
    post :unhold, { :CallSid => @freshfone_call.call_sid }
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response][:Dial]).to be_truthy
    expect(xml[:Response][:Dial][:Conference]).to be_truthy
    @freshfone_call.reload
    expect(@freshfone_call.inprogress?).to be true
    Freshfone::Providers::Twilio.any_instance.unstub(:unmute_participants)
    Twilio::REST::Conferences.any_instance.unstub(:get)
  end

  it 'should disconnect the agent from the call when there is an exception while unhold' do
    @account.freshfone_calls.destroy_all
    create_freshfone_conf_call('CONFCALL')
    @freshfone_call.update_attributes!({ :conference_sid => 'ConSid' })
    Freshfone::Call.any_instance.stubs(:inprogress!).raises(StandardError.new('Unknown Error'))
    set_twilio_signature("/freshfone/hold/unhold?call=#{@freshfone_call.id}", { :CallSid => @freshfone_call.call_sid })
    post :unhold, { :CallSid => @freshfone_call.call_sid }
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Call.any_instance.unstub(:inprogress!)
  end


  it 'should make the call to inprogress and add the customer to another conference while transferring' do
    @account.freshfone_calls.destroy_all
    parent_call = create_freshfone_conf_call('CONFCALL')
    create_conf_child_call('CONF_CHILD')
    parent_call.update_attributes!({ :conference_sid => "ConSid" })
    conference = mock
    Twilio::REST::Conferences.any_instance.stubs(:get).returns(conference)
    set_twilio_signature("/freshfone/hold/transfer_unhold?child_sid=CONF_CHILD&call=#{parent_call.id}", transfer_unhold_params.except(:child_sid,:call))
    Freshfone::Call.any_instance.stubs(:disconnect_source_agent)
    post :transfer_unhold, transfer_unhold_params
    parent_call.reload
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response][:Dial]).to be_truthy
    expect(xml[:Response][:Dial][:Conference]).to be_truthy
    expect(parent_call.children.last.inprogress?).to be true
    Twilio::REST::Conferences.any_instance.unstub(:get)
    Freshfone::Call.any_instance.unstub(:disconnect_source_agent)
  end

  it 'should disconnect the agent from the call when there is an exception while unhold' do
    @account.freshfone_calls.destroy_all
    parent_call = create_freshfone_conf_call('CONFCALL')
    create_conf_child_call('CONF_CHILD')
    parent_call.update_attributes!({ :conference_sid => 'ConSid' })
    Freshfone::Call.any_instance.stubs(:disconnect_source_agent).raises(StandardError.new('Unknown Error'))
    Freshfone::Call.any_instance.stubs(:disconnect_agent)
    set_twilio_signature("/freshfone/hold/transfer_unhold?child_sid=CONF_CHILD&call=#{parent_call.id}", transfer_unhold_params.except(:child_sid,:call))
    post :transfer_unhold, transfer_unhold_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Call.any_instance.unstub(:disconnect_source_agent)
  end

  it 'should remove the agent from the hold queue and return proper json when there is an exception while removing from hold' do
    @freshfone_call.update_attributes!({ :hold_queue => "HoldQ", :conference_sid => "ConSid", 
      :call_status => Freshfone::Call::CALL_STATUS_HASH[:'on-hold'] })
    queues = mock
    members = mock
    member = mock
    member.stubs(:dequeue).raises(StandardError.new('Unknown Error'))
    members.stubs(:get).returns(member)
    queues.stubs(:members).returns(members)
    Twilio::REST::Queues.any_instance.stubs(:get).returns(queues)
    get :remove, { :CallSid => @freshfone_call.call_sid }
    expect(json).to be_truthy
    expect(json).to eql({:status => "error"})
    Twilio::REST::Queues.any_instance.unstub(:get)
  end

  it "should fallback to source on transfered call unanswered" do
    @account.freshfone_calls.destroy_all
    parent_call = create_freshfone_conf_call('CONFCALL',Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
    child_call = create_conf_child_call('CONF_CHILD')
    child_call.update_attributes({:call_status => Freshfone::Call::CALL_STATUS_HASH[:'no-answer']})
    parent_call.update_attributes!({ :conference_sid => 'ConSid' })
    Freshfone::Call.any_instance.stubs(:disconnect_agent)
    Freshfone::Telephony::any_instance.stubs(:unmute_participants)
    set_twilio_signature("freshfone/hold/transfer_fallback_unhold?call=#{parent_call.id}", transfer_fallback_unhold_params.except(:call))
    post :transfer_fallback_unhold, transfer_fallback_unhold_params
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response][:Dial]).to be_truthy
    expect(xml[:Response][:Dial][:Conference]).to be_truthy
    Freshfone::Telephony::any_instance.unstub(:unmute_participants)
    Freshfone::Call.any_instance.unstub(:disconnect_agent)
  end

  it "should disconnect agent when an error occurred during fallback" do
    @account.freshfone_calls.destroy_all
    parent_call = create_freshfone_conf_call('CONFCALL',Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
    child_call = create_conf_child_call('CONF_CHILD')
    child_call.update_attributes({:call_status => Freshfone::Call::CALL_STATUS_HASH[:'no-answer']})
    parent_call.update_attributes!({ :conference_sid => 'ConSid' })
    Freshfone::Call.any_instance.stubs(:disconnect_agent)
    Freshfone::Call.any_instance.stubs(:inprogress!).raises(StandardError.new('Unknown Error'))
    set_twilio_signature("freshfone/hold/transfer_fallback_unhold?call=#{parent_call.id}", transfer_fallback_unhold_params.except(:call))
    post :transfer_fallback_unhold, transfer_fallback_unhold_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Call.any_instance.unstub(:disconnect_agent)
  end

  it 'should not allow any params which are not acceptable' do
    params = { :call_detail => 'unacceptable' }
    set_twilio_signature('hold/transfer_unhold', {})
    post :transfer_unhold, params
    expect(response.status).to eq(200)
    expect(response.body).to eq(' ')
  end

  it 'should render error when agent conference call is put on hold' do
    @freshfone_call.update_attributes!(:call_status => Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    create_dummy_freshfone_users(1, Freshfone::User::PRESENCE[:online])
    create_agent_conference_call(@dummy_users[0],
         Freshfone::SupervisorControl::CALL_STATUS_HASH[:'in-progress'], 'HOLDCONFCALL')
    get :add, CallSid:  @agent_conference_call.sid
    expect(json[:status]).to eql('error')
  end
end
