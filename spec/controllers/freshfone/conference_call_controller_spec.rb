require 'spec_helper'
load 'spec/support/freshfone_call_spec_helper.rb'
load 'spec/support/freshfone_spec_helper.rb'

RSpec.configure do |c|
  c.include FreshfoneCallSpecHelper
  c.include Redis::RedisKeys
  c.include Redis::IntegrationsRedis
end

RSpec.describe Freshfone::ConferenceCallController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account.freshfone_calls.destroy_all
  end

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    @account.freshfone_calls.destroy_all
    create_freshfone_user
    log_in @agent
  end

  it 'should give the status appropriately and should add cost job' do
  	create_freshfone_call
    create_call_meta
  	set_twilio_signature('freshfone/conference_call/status', conference_call_params.except(*[:direct_dial_number, :agent]))
  	call = mock
  	call.stubs(:update)
  	Twilio::REST::Calls.any_instance.stubs(:get).returns(call)
  	post :status, conference_call_params.except(*[:direct_dial_number, :agent])
  	expect(xml).to be_truthy
  	expect(xml.key?(:Response)).to be true
  	Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should throw exception while completing a call' do
    log_in @agent
    create_freshfone_call
    create_call_meta
    set_twilio_signature('freshfone/conference_call/status', conference_call_params.except(*[:direct_dial_number, :agent]))
    Freshfone::ConferenceCallController.any_instance.stubs(:complete_call).raises(Exception)
    post :status, conference_call_params.except(*[:direct_dial_number, :agent])
    puts "xml output : #{xml}"
    expect(xml).to be_truthy
    expect(xml.key?(:Response)).to be true
    Freshfone::ConferenceCallController.any_instance.unstub(:complete_call)
  end

  it 'should set dial call status as completed' do
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    create_call_meta
    set_twilio_signature('freshfone/conference_call/status', conference_call_params)
    call = mock
    call.stubs(:update)
    Twilio::REST::Calls.any_instance.stubs(:get).returns(call)
    post :status, conference_call_params
    expect(xml).to be_truthy
    expect(xml.key?(:Response)).to be true
    Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should handle direct call' do
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,:direct_dial_number => "+16617480240",
                                      :dial_call_sid =>"CA2db76c748cb6f081853f80dace462a04",
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    set_twilio_signature('freshfone/conference_call/status', conference_call_params)
    call = mock
    call.stubs(:update)
    Twilio::REST::Calls.any_instance.stubs(:get).returns(call)
    post :status, conference_call_params
    expect(xml).to be_truthy
    expect(xml.key?(:Response)).to be true
    Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should update total duration' do
    create_freshfone_call
    create_call_meta
    params=conference_call_params.merge(:CallDuration => 10)
    set_twilio_signature('freshfone/conference_call/status', params)
    call = mock
    call.stubs(:update)
    Twilio::REST::Calls.any_instance.stubs(:get).returns(call)
    post :status, params
    expect(xml).to be_truthy
    expect(xml.key?(:Response)).to be true
    Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should make the agent add to the conference while a conference call is incoming' do
  	create_freshfone_call
  	params = conference_call_params.except(*[:direct_dial_number, :agent]).merge(:CallStatus => Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
  	set_twilio_signature('freshfone/conference_call/in_call', params)
  	setup_batch
  	post :in_call, params
  	expect(xml).to be_truthy
  	expect(xml[:Response][:Dial]).to be_truthy
  	expect(xml[:Response][:Dial][:Conference]).to be_truthy
  end

  it 'should not allow any params which are not acceptable' do
    params = { :call_detail => 'unacceptable' }
    set_twilio_signature('freshfone/conference_call/in_call', {})
    post :in_call, params
    expect(response.status).to eq(200)
    expect(response.body).to eq(' ')
  end

  it 'should update call recording' do
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent, 
                                      :conference_sid => "ConSid", 
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" })
    params = conference_call_params
    set_twilio_signature('freshfone/conference_call/update_recording', params)
    post :update_recording, params
    expect(response.status).to eq(200)
    expect(response.body).should_not be_blank 
  end

  it 'should not update call recording' do
    create_freshfone_call
    params = conference_call_params
    set_twilio_signature('freshfone/conference_call/update_recording', params)
    post :update_recording, params
    expect(response.status).to eq(200)
  end

  it 'should disconnect the agent(s) when customer just rings and no agent(s) picked' do
    create_freshfone_call
    create_call_meta
    create_pinged_agents(false)
    @freshfone_call.update_column(:user_id, nil)
    stub_twilio_call(:get,[:update])
    (@account.freshfone_subaccount.calls.get).stubs(:status).stubs("ringing")
    params = conference_call_params.merge(:CallStatus => 'no-answer', :To => '+17022918906')
    set_twilio_signature("freshfone/conference_call/status", params)
    post :status, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should disconnect the transfer leg of conference call for its completion' do
    create_call_family
    create_call_meta(@parent_call)
    params = conference_call_params.merge(:CallStatus => 'completed', :To => '+17022918906')
    set_twilio_signature('freshfone/conference_call/status', params)
    @parent_call.update_column(:call_status, Freshfone::Call::CALL_STATUS_HASH[:completed])
    post :status, params
    @parent_call.children.first.reload
    expect(@parent_call.children.first.call_status).to eq(Freshfone::Call::CALL_STATUS_HASH[:completed])
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
  end

  it 'should save call notes when an agent transfers call to another agent' do
    create_call_family
    params = {:call_sid => @parent_call.children.first.call_sid, :call_notes => 'test'}
    post :save_call_notes, params
    expect(json).to be_truthy
    expect(json[:notes_saved]).to be true
  end

  it 'should get the saved call notes when an agent receives the transferred call' do 
    key = 'FRESHFONE:CALL_NOTE:1:CA1d4ae9fae956528fdf5e61a64084f191'
    $redis_integrations.set(key,'test')
    create_call_family
    params = {:PhoneNumber => @parent_call.children.first.caller.number}
    get :call_notes, params
    nil_notes = $redis_integrations.get(key)
    nil_notes.should be_nil
    expect(json).to be_truthy
    expect(json[:call_notes]).to be_eql('test')
  end

  it 'should get empty notes when notes not saved' do 
    create_call_family
    params = {:PhoneNumber => @parent_call.children.first.caller.number}
    get :call_notes, params
    expect(json).to be_truthy
    expect(json[:call_notes]).to be_blank
  end

  it 'should be blank notes when call is not a transferred call' do 
    create_freshfone_caller
    params = {:PhoneNumber => @caller.number}
    get :call_notes, params
    expect(json).to be_truthy
    expect(json[:call_notes]).to be_blank
  end

end
