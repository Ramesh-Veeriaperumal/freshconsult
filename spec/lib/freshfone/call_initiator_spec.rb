require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
include FreshfoneSpecHelper

describe Freshfone::CallInitiator do
  self.use_transactional_fixtures = false
  
  before(:all) do
    #@account = create_test_account
    @agent = get_admin
  end

  before(:each) do
    create_test_freshfone_account
  end
  
  it 'should render twiml that connects caller to specified numbers' do 
    caller = Faker::PhoneNumber.phone_number
    params = { :From => caller }
    call_flow = Freshfone::CallFlow.new(params, @account, @numbers, @agent)
    call_flow.numbers = ["+12345678900"]
    call_initiator = Freshfone::CallInitiator.new(params, @account, @number, call_flow)
    twiml = twimlify call_initiator.connect_caller_to_numbers
    twiml[:Response][:Dial][:callerId].should be_eql(caller)
    twiml[:Response][:Dial][:Number].should be_eql("+12345678900")
  end

  it 'should render twiml that initiates outgoing' do
    target_customer = Faker::PhoneNumber.phone_number
    params = { :PhoneNumber => target_customer }
    call_initiator = Freshfone::CallInitiator.new(params, @account, @number, nil)
    twiml = twimlify call_initiator.initiate_outgoing
    twiml[:Response][:Dial][:callerId].should be_eql(@number.number)
    twiml[:Response][:Dial][:Number].should be_eql(target_customer)
  end

  it 'should render twiml that initiates recording' do
    params = { :agent => @agent.id, :number_id => @number.id }
    call_initiator = Freshfone::CallInitiator.new(params, @account, @number, nil)
    twiml = twimlify call_initiator.initiate_recording
    twiml[:Response][:Record][:action].should eql "#{account_protocol}#{@account.full_domain}/freshfone/device/record?agent=#{@agent.id}&number_id=#{@number.id}"
  end

  it 'should render twiml that adds a caller to queue' do
    call_initiator = Freshfone::CallInitiator.new({}, @account, @number, nil)
    twiml = call_initiator.add_caller_to_queue({:type => :agent, :performer => @agent.id})
    twiml.should match(/hunt_type=agent&amp;hunt_id=#{@agent.id}/)
  end

  it 'should render twiml for blocking incoming call' do
    call_initiator = Freshfone::CallInitiator.new({}, @account, @number, nil)
    twiml = twimlify call_initiator.block_incoming_call
    twiml.should be_eql({:Response=>{:Reject=>{:reason=>"busy"}}})
  end

  it 'should render twiml that returns a non business hour call message' do
    # @number.update_attributes(:voicemail_active => true)
    call_initiator = Freshfone::CallInitiator.new({}, @account, @number, nil)
    twiml = twimlify call_initiator.return_non_business_hour_call
    twiml[:Response][:Say].first.should match(@number.non_business_hours_message.message)
  end

  it 'should return false for empty queue' do
    call_initiator = Freshfone::CallInitiator.new({}, @account, @number, nil)
    call_initiator.send(:queue_overloaded?).should be_false
  end
  

end 