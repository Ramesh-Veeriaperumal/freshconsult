require 'spec_helper'
load 'spec/support/freshfone_actions_spec_helper.rb'

RSpec.configure do |c|
  c.include FreshfoneActionsSpecHelper
end

RSpec.describe 'CallRecordingAttachment' do
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @agent = get_admin
  end

  before(:each) do
    create_test_freshfone_account
  end

  it 'should fetch twilio recording' do
    call = create_freshfone_call
    call.update_attributes(:recording_url => "#{Rails.root}/spec/fixtures/files/callrecording")
    args = {:call_id => call.id, :call_sid => call.call_sid}
    Twilio::REST::Recording.any_instance.stubs(:duration).returns(10)
    Freshfone::Jobs::CallRecordingAttachment.stubs(:release_data).returns(true)
    Freshfone::Jobs::CallRecordingAttachment.perform_job(args)
    call.reload
    call.recording_audio.should be_an_instance_of(Helpdesk::Attachment)
    call.recording_audio.attachable_id.should be_eql(call.id)
    Twilio::REST::Recording.any_instance.unstub(:duration)
    Freshfone::Jobs::CallRecordingAttachment.unstub(:release_data)
  end

  it 'should nullify recording url if recording less than 5 seconds' do
    call = create_freshfone_call
    call.update_attributes(:recording_url => 
      "http://api.twilio.com/2010-04-01/Accounts/AC9fa514fa8c52a3863a76e2d76efa2b8e/Recordings/REfb9a761e0744305cb0d1270603e91076")
    args = {:call_id => call.id, :call_sid => call.call_sid}
    Twilio::REST::Recording.any_instance.stubs(:duration).returns(1)
    Freshfone::Jobs::CallRecordingAttachment.perform_job(args)
    call.reload
    call.recording_audio.should be_blank
    call.recording_url.should be_blank
  end

  it 'should not create the audio attachment, if the recording is deleted by the user already' do
    call = create_freshfone_call
    call.update_attributes(:recording_url => 
      "http://api.twilio.com/2010-04-01/Accounts/AC9fa514fa8c52a3863a76e2d76efa2b8e/Recordings/REbd383eb591106df8d80bb556d3b6f59e")
    args = {:call_id => call.id, :call_sid => call.call_sid}
    recording = mock()
    Twilio::REST::Recordings.any_instance.stubs(:get).returns(recording)
    recording.stubs(:delete).returns(true)
    call.delete_recording(@agent.id)
    Freshfone::Jobs::CallRecordingAttachment.perform_job(args)
    call.reload
    expect(call.recording_audio).to be_nil
    Twilio::REST::Recordings.any_instance.unstub(:get)
  end

end

RSpec.describe 'CallQueueWait' do
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @agent = get_admin
    create_test_freshfone_account
  end

  it 'should not dequeue a call which is not present in the twilio queue' do
    call = create_freshfone_call
    queued_twiml = Freshfone::QueueWait.perform({
      :queue_sid => @account.freshfone_account.queue, 
      :call_sid => call.call_sid})
    queued_twiml.should be_blank
  end
end

describe 'BusyResolve' do

  before(:each) do
    create_test_freshfone_account
    create_freshfone_user
  end
  
  it 'should reset presence of the user if found to be not in a call' do
    @freshfone_user.busy!
    Freshfone::Jobs::BusyResolve.stubs(:no_active_calls).returns(true)
    Freshfone::Jobs::BusyResolve.perform(:agent_id => @freshfone_user.user_id)
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_offline
  end

  it 'should not reset presence of the user if found to be in a call' do
    @freshfone_user.busy!
    Freshfone::Jobs::BusyResolve.stubs(:no_active_calls).returns(false)
    Freshfone::Jobs::BusyResolve.perform(:agent_id => @freshfone_user.user_id)
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_busy
  end
end

describe 'UsageTrigger' do
	self.use_transactional_fixtures = false

	before(:each) do
		create_test_freshfone_account
	end

	after(:each) do
		@account.freshfone_account.freshfone_usage_triggers.delete_all
	end

	it 'should remove second level daily threshold triggers upon security whitelisting' do
		freshfone_account = @account.freshfone_account
		Resque.inline = true
		create_test_usage_triggers
		freshfone_account.reload
		freshfone_account.freshfone_usage_triggers.reload
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(2)
		trigger = mock
		trigger.stubs(:delete)
		Freshfone::Jobs::UsageTrigger.stubs(:get_trigger).returns(trigger)
		freshfone_account.do_security_whitelist
		Resque.inline = false
		freshfone_account.freshfone_usage_triggers.reload
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(1)
		Freshfone::Jobs::UsageTrigger.unstub(:get_trigger)
	end

	it 'should create second level daily threshold trigger upon security unwhitelisting' do
		freshfone_account = @account.freshfone_account
		freshfone_account.update_column(:security_whitelist, true)
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(0)
		trigger = mock
		trigger.stubs(:sid).returns('TRIGR')
		trigger.stubs(:current_value).returns('0')
		trigger.stubs(:trigger_value).returns('100')
		Twilio::REST::Triggers.any_instance.stubs(:create).returns(trigger)
		Resque.inline = true
		freshfone_account.undo_security_whitelist
		Resque.inline = false
		freshfone_account.freshfone_usage_triggers.reload
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(1)
		Twilio::REST::Triggers.any_instance.unstub(:create)
	end

end
