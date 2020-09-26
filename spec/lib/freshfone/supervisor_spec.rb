require 'spec_helper'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include Redis::IntegrationsRedis
  c.include FreshfoneSpecHelper
end

RSpec.describe Freshfone::Initiator::Supervisor do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

    before(:all) do
      @account.freshfone_calls.destroy_all
      @agent = get_admin
    end

    before(:each) do
      create_test_freshfone_account
      @account.freshfone_calls.destroy_all
      @account.freshfone_callers.delete_all
      @account.features.freshfone_call_monitoring.create
      @account.features.reload
      create_freshfone_user
      @freshfone_call = create_freshfone_call
      @freshfone_call.update_attributes(:call_status => Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
      Freshfone::Initiator::Supervisor.any_instance.stubs(:current_call).returns(@freshfone_call)
    end

    after(:each) do
      outgoing_key = FRESHFONE_OUTGOING_CALLS_DEVICE % { :account_id => @account.id }
      remove_key(outgoing_key)
      Freshfone::Initiator::Supervisor.any_instance.unstub(:current_call)
    end

    it 'should create supervisor control' do
        outgoing_key = FRESHFONE_OUTGOING_CALLS_DEVICE % { :account_id => @account.id }
        remove_key(outgoing_key)
        Freshfone::Initiator::Supervisor.any_instance.stubs(:supervisable?).returns(true)
        Freshfone::Initiator::Supervisor.any_instance.stubs(:register_outgoing_device).returns(true)
        @freshfone_call.supervisor_controls.count.should eql 0
        supervisor=Freshfone::Initiator::Supervisor.new(supervisor_params , @account, @number)
        result= supervisor.process   
        expect(result).to match(/Response/)
        expect(result).to match(/Dial/)
        expect(result).to match(/Conference/)
        @freshfone_call.reload
        @freshfone_call.supervisor_controls.count.should eql 1
        supervisor_leg_key = FRESHFONE_SUPERVISOR_LEG % { :account_id => @account.id, :user_id => @agent.id, :call_sid => supervisor_params[:CallSid] }
        get_key(supervisor_leg_key).should_not be_nil
        remove_key(supervisor_leg_key)
        Freshfone::Initiator::Supervisor.any_instance.unstub(:supervisable?)
        Freshfone::Initiator::Supervisor.any_instance.unstub(:register_outgoing_device)
    end

    it 'should not create supervisor control when call monitoring not enabled' do
        @account.features.freshfone_call_monitoring.destroy
        @account.features.reload
        Freshfone::Initiator::Supervisor.any_instance.stubs(:supervisable?).returns(false)
        supervisor=Freshfone::Initiator::Supervisor.new(supervisor_params , @account, @number)
        result= supervisor.process   
        expect(result).to match(/Response/)
        expect(result).to match(/Reject/)
        @freshfone_call.reload
        @freshfone_call.supervisor_controls.count.should eql 0
        Freshfone::Initiator::Supervisor.any_instance.unstub(:supervisable?)
    end

    it 'should not create supervisor control for call that is completed' do
        @freshfone_call.update_attributes(:call_status => Freshfone::Call::CALL_STATUS_HASH[:completed])
        Freshfone::Initiator::Supervisor.any_instance.stubs(:supervisable?).returns(false)
        supervisor=Freshfone::Initiator::Supervisor.new(supervisor_params , @account, @number)
        result= supervisor.process   
        expect(result).to match(/Response/)
        expect(result).to match(/Reject/)
        @freshfone_call.reload
        @freshfone_call.supervisor_controls.count.should eql 0
        Freshfone::Initiator::Supervisor.any_instance.unstub(:supervisable?)
    end

    it 'should not create supervisor control for already monitored call' do
        create_supervisor_call @freshfone_call
        Freshfone::Initiator::Supervisor.any_instance.stubs(:supervisable?).returns(false)
        supervisor=Freshfone::Initiator::Supervisor.new(supervisor_params , @account, @number)
        result= supervisor.process   
        expect(result).to match(/Response/)
        expect(result).to match(/Reject/)
        @freshfone_call.reload
        @freshfone_call.supervisor_controls.count.should eql 1
        Freshfone::Initiator::Supervisor.any_instance.unstub(:supervisable?)
    end

    it 'should not create supervisor control if device is already busy' do
        outgoing_key = FRESHFONE_OUTGOING_CALLS_DEVICE % { :account_id => @account.id }
        add_to_set(outgoing_key, @agent.id)
        supervisor=Freshfone::Initiator::Supervisor.new(supervisor_params , @account, @number)
        result= supervisor.process   
        expect(result).to match(/Response/)
        expect(result).to match(/Reject/)
        @freshfone_call.reload
        @freshfone_call.supervisor_controls.count.should eql 0
        remove_value_from_set(outgoing_key, @agent.id)
    end
end