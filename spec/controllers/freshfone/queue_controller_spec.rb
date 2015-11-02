require 'spec_helper'

RSpec.configure do |c|
  c.include FreshfoneQueueHelper
  c.include Freshfone::Queue
end

RSpec.describe Freshfone::QueueController do
  
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @account.features.freshfone_conference.delete if @account.features?(:freshfone_conference)
    @account.reload
    @request.host = @account.full_domain
  end

  it 'should render enqueue twiml for a normal queue call' do
    set_twilio_signature('freshfone/queue/enqueue?hunt_type=&hunt_id=', queue_params)
    create_freshfone_call('CAae09f7f2de39bd201ac9276c6f1cc66a')
    create_call_meta
    post :enqueue, queue_params
    xml[:Response][:Gather][:Play].should be_eql("http://com.twilio.music.guitars.s3.amazonaws.com/Pitx_-_A_Thought.mp3")
  end

  it 'should render voicemail twiml on triggering voicemail from queue' do 
    set_twilio_signature('freshfone/queue/trigger_voicemail', queue_params)
    post :trigger_voicemail, queue_params
    xml[:Response][:Say].should_not be_blank
  end

  it 'should render non-availability twiml on wait time expiry' do
  	@account.features.freshfone_conference.delete if @account.features?(:freshfone_conference)
    set_twilio_signature('freshfone/queue/trigger_non_availability', queue_params)
    post :trigger_non_availability, queue_params
    xml[:Response][:Say].should_not be_blank
  end

  it 'should remove call sid for a call not in-progress from the queue' do
    log_in(@agent)
    controller.send(:queued_members).stubs(:list).returns(["random"])
    controller.set_key( "FRESHFONE:CALLS:QUEUE:#{@account.id}", 
                        ["CAae09f7f2de39bd201ac9276c6f1cc66a"].to_json )
    post :bridge
    controller.get_key( "FRESHFONE:CALLS:QUEUE:#{@account.id}").should be_eql([].to_json)
  end

  it 'should success json when queue list is empty' do
    log_in(@agent)
    stub_twilio_queues
    post :bridge
    json.should be_eql({:status => "success"})
    Twilio::REST::Queues.any_instance.unstub(:get)
  end

  it 'should dequeue twiml on call dequeue' do
  	@account.features.freshfone_conference.delete if @account.features?(:freshfone_conference)
    create_freshfone_call('CAb5ce7735068c8cd04a428ed9a57ef64e')
    set_twilio_signature("freshfone/queue/dequeue?client=#{@agent.id}", dequeue_params)
    create_online_freshfone_user
    post :dequeue, dequeue_params.merge({"client" => @agent.id})
    xml[:Response][:Dial][:Client].should include(@agent.id.to_s)
  end

  it 'should remove all default queue entries from redis on hangup' do # failing in master
    set_twilio_signature('freshfone/queue/hangup', hangup_params)
    create_freshfone_call('CDEFAULTQUEUE')
    set_default_queue_redis_entry
    post :hangup, hangup_params
    controller.get_key(FreshfoneQueueHelper::DEFAULT_QUEUE % {account_id: @account.id}).should be_nil
  end

  it 'should remove all agent priority queue entries from redis on hangup' do # failing in master
    set_twilio_signature("freshfone/queue/hangup?hunt_type=agent&hunt_id=#{@agent.id}",
                           hangup_params.merge({"CallSid" => "CAGENTQUEUE"}))
    create_freshfone_call('CAGENTQUEUE')
    set_agent_queue_redis_entry
    post :hangup, 
      hangup_params.merge({:hunt_type => "agent", :hunt_id => @agent.id, "CallSid" => "CAGENTQUEUE"})
    controller.get_key(FreshfoneQueueHelper::AGENT_QUEUE % {account_id: @account.id}).should be_nil
  end

  it 'should render dequeue twiml on queue to voicemail' do
    set_twilio_signature('freshfone/queue/quit_queue_on_voicemail', dequeue_params)
    Twilio::REST::Member.any_instance.stubs(:dequeue)
    post :quit_queue_on_voicemail, dequeue_params
    response.body.should be_eql("Dequeued Call CAb5ce7735068c8cd04a428ed9a57ef64e from QU629430fd5b8d41769b02abfe7bfbe3a9")
  end

  it 'should fetch the calls waiting in queue for an agent: agent hunted call' do
    log_in @agent
    
    agent_key = "FRESHFONE:AGENT_QUEUE:#{@account.id}"
    controller.remove_key agent_key
    controller.set_key(agent_key, {@agent.id => ["CAGENTHUNTEDCALL"]}.to_json)

    controller.stubs(:bridge_priority_call)
    list = mock()
    list.stubs(:list).returns(["dummy queued member"])
    controller.stubs(:queued_members).returns(list)
    
    post :bridge
    assigns[:priority_call].should match("CAGENTHUNTEDCALL")

    controller.remove_key agent_key
  end

  it 'should fetch the calls waiting in queue for a group: group hunted call' do
    log_in @agent
    group = create_group @account, {:name => "Freshfone Group"}
    AgentGroup.new(:user_id => @agent.id , :account_id => @account.id, :group_id => group.id).save!    
    
    group_key = "FRESHFONE:GROUP_QUEUE:#{@account.id}"
    controller.remove_key group_key
    controller.set_key(group_key, {group.id => ["CGROUPHUNTEDCALL"]}.to_json)

    controller.stubs(:bridge_priority_call)
    list = mock()
    list.stubs(:list).returns(["dummy queued member"])
    controller.stubs(:queued_members).returns(list)
    
    post :bridge
    assigns[:priority_call].should match("CGROUPHUNTEDCALL")

    controller.remove_key group_key
  end

  it 'should update call queue abandon status on customer hangup' do
    set_twilio_signature('freshfone/queue/hangup', hangup_params)
    freshfone_call = create_freshfone_call('CDEFAULTQUEUE')
    post :hangup, hangup_params
    freshfone_call = @account.freshfone_calls.find(freshfone_call)
    abandon_state = Freshfone::Call::CALL_ABANDON_TYPE_HASH[:queue_abandon]
    freshfone_call.abandon_state.should be_eql(abandon_state)
  end
  
  it 'should render dequeue twiml on queue to voicemail' do
    set_twilio_signature('freshfone/queue/quit_queue_on_voicemail', dequeue_params)
    freshfone_call = create_freshfone_call('CDEFAULTQUEUE')
    Twilio::REST::Member.any_instance.stubs(:dequeue)
    post :quit_queue_on_voicemail, dequeue_params
    response.body.should be_eql("Dequeued Call CAb5ce7735068c8cd04a428ed9a57ef64e from QU629430fd5b8d41769b02abfe7bfbe3a9")
    freshfone_call = @account.freshfone_calls.find(freshfone_call)
    freshfone_call.should be_default
    freshfone_call.abandon_state.should be_nil
  end
end