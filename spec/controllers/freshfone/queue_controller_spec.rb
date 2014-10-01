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
    @request.host = RSpec.configuration.account.full_domain
  end

  it 'should render enqueue twiml for a normal queue call' do
    set_twilio_signature('freshfone/queue/enqueue?hunt_type=&hunt_id=', queue_params)
    post :enqueue, queue_params
    xml[:Response][:Gather][:Play].should be_eql("http://com.twilio.music.guitars.s3.amazonaws.com/Pitx_-_A_Thought.mp3")
  end

  it 'should render voicemail twiml on triggering voicemail from queue' do 
    set_twilio_signature('freshfone/queue/trigger_voicemail', queue_params)
    post :trigger_voicemail, queue_params
    xml[:Response][:Say].should_not be_blank
  end

  it 'should render non-availability twiml on wait time expiry' do
    set_twilio_signature('freshfone/queue/trigger_non_availability', queue_params)
    post :trigger_non_availability, queue_params
    xml[:Response][:Say].should_not be_blank
  end

  it 'should raise error whe trying to dequeue calls not in-progress' do
    log_in(@agent)
    controller.send(:queued_members).stubs(:list).returns(["random"])
    controller.set_key( "FRESHFONE:CALLS:QUEUE:#{@account.id}", 
                        ["CAae09f7f2de39bd201ac9276c6f1cc66a"].to_json )
    lambda { post :bridge }.should raise_error(Twilio::REST::RequestError, /Cannot dequeue call/)
  end

  it 'should success json when queue list is empty' do
    log_in(@agent)
    post :bridge
    json.should be_eql({:status => "success"})
  end

  it 'should dequeue twiml on call dequeue' do
    set_twilio_signature("freshfone/queue/dequeue?client=#{@agent.id}", dequeue_params)
    create_online_freshfone_user
    post :dequeue, dequeue_params.merge({"client" => RSpec.configuration.agent.id})
    xml[:Response][:Dial][:Client].should include(@agent.id.to_s)
  end

  xit 'should remove all default queue entries from redis on hangup' do#TODO-RAILS3 FAILING ON MASTER
    set_twilio_signature('freshfone/queue/hangup', hangup_params)
    set_default_queue_redis_entry
    post :hangup, hangup_params
    controller.get_key(DEFAULT_QUEUE).should be_nil
  end

  xit 'should remove all agent priority queue entries from redis on hangup' do#TODO-RAILS3 FAILING ON MASTER
    set_twilio_signature("freshfone/queue/hangup?hunt_type=agent&hunt_id=#{@agent.id}",
                           hangup_params.merge({"CallSid" => "CAGENTQUEUE"}))
    set_agent_queue_redis_entry
    post :hangup, 
      hangup_params.merge({:hunt_type => "agent", :hunt_id => RSpec.configuration.agent.id, "CallSid" => "CAGENTQUEUE"})
    controller.get_key(AGENT_QUEUE).should be_nil
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
    group = create_group RSpec.configuration.account, {:name => "Freshfone Group"}
    AgentGroup.new(:user_id => RSpec.configuration.agent.id , :account_id => RSpec.configuration.account.id, :group_id => group.id).save!    
    
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
end