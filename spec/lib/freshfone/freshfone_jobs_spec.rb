require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
include FreshfoneSpecHelper

describe 'CallRecordingAttachment' do
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @agent = get_admin
  end

  before(:each) do
    create_test_freshfone_account
  end

  it 'should fetch twilio recording' do
    call = create_freshfone_call
    call.update_attributes(:recording_url => 
      "http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b")
    args = {:call_id => call.id, :call_sid => call.call_sid}
    Freshfone::Jobs::CallRecordingAttachment.perform_job(args)
    call.reload
    call.recording_audio.should be_an_instance_of(Helpdesk::Attachment)
    call.recording_audio.attachable_id.should be_eql(call.id)
  end

  it 'should nullify recording url if recording less than 5 seconds' do
    call = create_freshfone_call
    call.update_attributes(:recording_url => 
      "http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b")
    args = {:call_id => call.id, :call_sid => call.call_sid}
    Twilio::REST::Recording.any_instance.stubs(:duration).returns(1)
    Freshfone::Jobs::CallRecordingAttachment.perform_job(args)
    call.reload
    call.recording_audio.should be_blank
    call.recording_url.should be_blank
  end

  it 'should nullify recording url if recording less than 5 seconds' do
    call = create_freshfone_call
    call.update_attributes(:recording_url => 
      "http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b")
    args = {:call_id => call.id, :call_sid => call.call_sid}
    Freshfone::Jobs::CallRecordingAttachment.stubs(:fetch_twilio_recording).raises(Twilio::REST::RequestError)
    expect{ Freshfone::Jobs::CallRecordingAttachment.perform_job(args) }.to raise_error
  end
end

describe 'CallQueueWait' do
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
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