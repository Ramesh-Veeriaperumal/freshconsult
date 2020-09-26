require 'spec_helper'
load 'spec/support/freshfone_call_spec_helper.rb'
load 'spec/support/freshfone_spec_helper.rb'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include FreshfoneCallSpecHelper
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
    create_call_meta
  	params = conference_call_params.except(*[:direct_dial_number, :agent]).merge(:CallStatus => 'in-progress')
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
    params = {call_id: @parent_call.children.first.id, call_notes: 'test'}
    post :save_notable, params
    expect(json).to be_truthy
    expect(json[:notes_saved]).to be true
  end

  it 'should get the saved call notes when an agent receives the transferred call' do
    create_call_family 
    key = "FRESHFONE:CALL_NOTE:1:#{@parent_call.id}"
    $redis_integrations.set(key,'test')
    params = {:PhoneNumber => @parent_call.children.first.caller.number}
    get :load_notable, params
    nil_notes = $redis_integrations.get(key)
    nil_notes.should be_nil
    expect(json).to be_truthy
    expect(json[:call_notes]).to be_eql('test')
  end

  it 'should get empty notes when notes not saved' do 
    create_call_family
    params = {:PhoneNumber => @parent_call.children.first.caller.number}
    get :load_notable, params
    expect(json).to be_truthy
    expect(json[:call_notes]).to be_blank
  end

  it 'should be blank notes when call is not a transferred call' do 
    create_freshfone_caller
    params = {:PhoneNumber => @caller.number}
    get :load_notable, params
    expect(json).to be_truthy
    expect(json[:call_notes]).to be_blank
  end

  it 'should save added ticket-details when an agent transfers call to another agent' do
    create_call_family
    params = {call_id: @parent_call.children.first.id,
      ticket_details: '11 Call with Sachin Kumar'}
    post :save_notable, params
    expect(json).to be_truthy
    expect(json[:ticket_set]).to be true
  end

  it 'should get the saved added ticket-details when an agent receives the transferred call' do
    create_call_family 
    key = "FRESHFONE:CALL_TICKET:1:#{@parent_call.id}"
    $redis_integrations.set(key,'12 Call with Sachin Kumar')
    params = {PhoneNumber: @parent_call.children.first.caller.number}
    get :load_notable, params
    nil_notes = $redis_integrations.get(key)
    nil_notes.should be_nil
    expect(json).to be_truthy
    expect(json[:ticket_details]).to be_eql('12 Call with Sachin Kumar')
  end

  it 'should be blank ticket-details when call is not a transferred call' do 
    create_freshfone_caller
    params = {PhoneNumber: @caller.number}
    get :load_notable, params
    expect(json).to be_truthy
    expect(json[:ticket_details]).to be_blank
  end

  it 'should get empty ticket-details when ticket not added' do 
    create_call_family
    params = {PhoneNumber: @parent_call.children.first.caller.number}
    get :load_notable, params
    expect(json).to be_truthy
    expect(json[:ticket_details]).to be_blank
  end

  it 'should update ringing abandon status on force termination' do
    Freshfone::Number.any_instance.stubs(:working_hours?).returns(true)
    status_call = create_call_for_status_with_out_agent
    create_call_meta
    params=conference_call_params.merge(:DialCallStatus => 'no-answer',:CallStatus => 'completed')
    set_twilio_signature('freshfone/conference_call/status', params)
    post :status, params
    freshfone_call = @account.freshfone_calls.find(status_call)
    abandon_state = Freshfone::Call::CALL_ABANDON_TYPE_HASH[:ringing_abandon]
    freshfone_call.abandon_state.should be_eql(abandon_state)
  end

  it 'should update call IVR abandon status on customer hangup' do
    Freshfone::Number.any_instance.stubs(:working_hours?).returns(true)
    status_call = create_call_for_status_with_out_agent
    create_call_meta
    params=conference_call_params.merge(:DialCallStatus => 'no-answer',:CallStatus => 'completed')
    set_twilio_signature('freshfone/conference_call/status', params)
    Freshfone::Number.any_instance.stubs(:ivr_enabled?).returns(true)
    post :status, params
    freshfone_call = @account.freshfone_calls.find(status_call)
    abandon_state = Freshfone::Call::CALL_ABANDON_TYPE_HASH[:ivr_abandon]
    freshfone_call.abandon_state.should be_eql(abandon_state)
  end

  it 'should not update call abandon status on customer hangup for answered call' do
    status_call = create_freshfone_call
    params=conference_call_params.merge(:DialCallStatus => 'completed',:CallStatus => 'completed')
    set_twilio_signature('freshfone/conference_call/status', params)
    post :status, conference_call_params
    freshfone_call = @account.freshfone_calls.find(status_call)
    freshfone_call.abandon_state.should be_nil
  end

   it 'should have a rating' do
    create_freshfone_call
    create_call_meta
    params = {:CallSid => @freshfone_call.call_sid, :rating => "good" }
    put :wrap_call, params
    expect(json).to be_truthy
    expect(json[:result]).to be true
    @freshfone_call_meta.reload
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:good)
  end

  it 'should have an issue for bad calls' do
    create_freshfone_call
    create_call_meta
    params = {:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "bad", :issue => 'dropped_call'}
    put :wrap_call, params
    expect(json).to be_truthy
    expect(json[:result]).to be true
    @freshfone_call_meta.reload
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:bad)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(:dropped_call)
  end

   it 'should have comment for other issues' do
    create_freshfone_call
    create_call_meta
    params = {:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "bad", :issue => 'other_issues', :comment => "Bad Call Quality"}
    put :wrap_call, params
    expect(json).to be_truthy
    expect(json[:result]).to be true
    @freshfone_call_meta.reload
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:bad)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(:other)
    @freshfone_call_meta.meta_info[:quality_feedback][:comment].should be_eql("Bad Call Quality")
  end

  it 'should not have call feedback' do
    create_freshfone_call
    create_call_meta
    params = {:CallSid => "CA2db76c748cb6f081853f80dace462a04"}
    put :wrap_call, params
    expect(json).to be_truthy
    expect(json[:result]).to be true
    @freshfone_call_meta.reload
    @freshfone_call_meta.meta_info[:quality_feedback].should be(nil)
  end

  it 'should not have issue for good calls' do
    create_freshfone_call
    create_call_meta
    params = {:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "good"}
    put :wrap_call, params
    expect(json).to be_truthy
    expect(json[:result]).to be true
    @freshfone_call_meta.reload
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:good)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(nil)
    @freshfone_call_meta.meta_info[:quality_feedback][:comment].should be_eql(nil)
  end

  it 'should not have comment' do
    create_freshfone_call
    create_call_meta
    params = {:CallSid => "CA2db76c748cb6f081853f80dace462a04", :rating => "bad", :issue => 'dropped_call'}
    put :wrap_call, params
    expect(json).to be_truthy
    expect(json[:result]).to be true
    @freshfone_call_meta.reload
    @freshfone_call_meta.meta_info[:quality_feedback][:rating].should be_eql(:bad)
    @freshfone_call_meta.meta_info[:quality_feedback][:issue].should be_eql(:dropped_call)
    @freshfone_call_meta.meta_info[:quality_feedback][:comment].should be_eql(nil)
  end

  describe "Supervisor Leg Ends" do
    
    before :each do
      @account.freshfone_calls.destroy_all
      @account.freshfone_callers.delete_all
      @account.features.freshfone_call_monitoring.create
      @freshfone_call = create_freshfone_call
      @supervisor_control= create_supervisor_call @freshfone_call
      @supervisor_leg_key = FRESHFONE_SUPERVISOR_LEG % { :account_id => @account.id, :user_id => @agent.id, :call_sid => @supervisor_control.sid }
      @outgoing_key = FRESHFONE_OUTGOING_CALLS_DEVICE % { :account_id => @account.id }
      add_to_set(@outgoing_key, @agent.id)
    end

    it 'should update supervisor control' do
      set_twilio_signature('freshfone/conference_call/status', supervisor_call_status_params)
      post :status, supervisor_call_status_params
      expect(xml).to be_truthy
      expect(xml.key?(:Response)).to be true
      @supervisor_control.reload
      expect(@supervisor_control.supervisor_control_status).to eq(Freshfone::SupervisorControl::CALL_STATUS_HASH[:success])
      expect(@supervisor_control.duration).to eq(6)
    end


    it 'should remove outgoing_key on updating supervisor control' do
      set_twilio_signature('freshfone/conference_call/status', supervisor_call_status_params)
      post :status, supervisor_call_status_params
      expect(xml).to be_truthy
      expect(xml.key?(:Response)).to be true
      expect(remove_value_from_set(@outgoing_key,@agent.id)).to be false
    end

    it 'should remove supervisor_leg_key on updating supervisor control' do
      set_twilio_signature('freshfone/conference_call/status', supervisor_call_status_params)
      post :status, supervisor_call_status_params
      expect(xml).to be_truthy
      expect(xml.key?(:Response)).to be true
      get_key(@supervisor_leg_key).should be_nil
    end

    it 'should not update supervisor control when no supervisor_control with given Call sid is found' do
      set_twilio_signature('freshfone/conference_call/status', conference_call_params)
      post :status, conference_call_params
      expect(xml).to be_truthy
      expect(xml.key?(:Response)).to be true
      @supervisor_control.reload
      expect(@supervisor_control.supervisor_control_status).to eq(Freshfone::SupervisorControl::CALL_STATUS_HASH[:default])
      expect(@supervisor_control.duration).to be nil
    end

    it 'should not remove outgoing redis key when supervisor control updated with wrong call sid' do
      set_twilio_signature('freshfone/conference_call/status', conference_call_params)
      post :status, conference_call_params
      expect(xml).to be_truthy
      expect(xml.key?(:Response)).to be true
      expect(remove_value_from_set(@outgoing_key,@agent.id)).to be true
      remove_key @supervisor_leg_key
    end

    it 'should not remove supervisor leg redis key when supervisor control updated with wrong call sid' do
      set_twilio_signature('freshfone/conference_call/status', conference_call_params)
      post :status, conference_call_params
      expect(xml).to be_truthy
      expect(xml.key?(:Response)).to be true
      get_key(@supervisor_leg_key).should_not be_nil
      remove_value_from_set(@outgoing_key,@agent.id)
    end
  end

end
