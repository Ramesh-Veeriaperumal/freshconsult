require 'spec_helper'

RSpec.configure do |c|
  c.include Redis::RedisKeys
  c.include Redis::IntegrationsRedis
end

RSpec.describe FreshfoneController do
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
    Freshfone::Number.any_instance.stubs(:working_hours?).returns(true)
  end

  after(:each) do
    Freshfone::Number.any_instance.unstub(:working_hours?)
  end

  #Spec for Freshfone base controller
  it 'should custom-validate request from Twilio and allow call' do
    create_freshfone_call
    modified_params = incoming_params.merge('caller_sid' => @freshfone_call.id) 
    set_twilio_signature('freshfone/voice', modified_params.except('caller_sid'))
    post :voice, modified_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

  it 'should fail on extremely low freshfone credit' do
    set_twilio_signature('freshfone/voice', incoming_params)
    @account.freshfone_credit.update_attributes(:available_credit => 0.1)
    post :voice, incoming_params
    xml.should be_eql({:Response=>{:Reject=>nil}})
  end

  it 'should fail on missing freshfone feature' do
    set_twilio_signature('freshfone/voice', incoming_params)
    @account.features.freshfone.destroy
    post :voice, { :format => "html" }
    response.body.should include('freshfone enabled validation failed')
  end

  it 'should redirect to login when non-twilio-aware methods are called by not logged in users' do
    get :dashboard_stats, { :format => "json" }
    expected = {
      :require_login => true
    }.to_json
    response.body.should be_eql(expected)
  end
  #End spec for freshfone base controller. 
  #Change this to contexts


  #Spec for actual freshfone_controller
  it 'should render valid twiml on ivr_flow' do
    request.env["HTTP_ACCEPT"] = "application/xml"
    set_twilio_signature('freshfone/ivr_flow?menu_id=0', ivr_flow_params.except("menu_id"))
    @account.ivrs.create({:freshfone_number_id=>1})
    post :ivr_flow, ivr_flow_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

  it 'should render valid twiml on voice_fallback' do
    set_twilio_signature('freshfone/voice_fallback', fallback_params)
    post :voice_fallback, fallback_params
    xml.should have_key(:Response)
  end

  it 'should render valid json on dashboard_stats' do
    log_in(@agent)
    key = Redis::RedisKeys::NEW_CALL % {:account_id => @account.id}
    create_freshfone_user
    add_to_set(key, "1234")
    @freshfone_user.update_attributes(:incoming_preference => 1, :presence => 2)
    get :dashboard_stats, { :format => "json" }
    expected = {
      :available_agents => @account.freshfone_users.online_agents.count,
      :active_calls => get_count_from_integ_redis_set(key)
    }.to_json
    response.body.should be_eql(expected)
  end

  it "must be routable to the dial_check action" do
     { :get => "freshfone/dial_check" }.should be_routable
  end

  it 'should render valid json on dial_check' do
    log_in(@agent)
    get :dial_check, { :phone_number => "+918754693849" } 
    result = JSON.parse(response.body).symbolize_keys
    result.has_key?(:status)
    result.has_key?(:code)
  end

  it 'should respond with ok status' do
    log_in(@agent)
    get :dial_check, { :phone_number => "+918754693849", :is_country => "true" }
    result = JSON.parse(response.body).symbolize_keys
    result.should include(:status => "ok") 
  end

  it 'should respond with low credit status' do
    log_in(@agent)
    @account.freshfone_credit.update_attributes(:available_credit => 0.1)
    get :dial_check, { :phone_number => "+918754693849" } 
    result = JSON.parse(response.body).symbolize_keys
    result.should include(:status => "low_credit") 
  end

  it 'should respond with dial restricted country status' do
    log_in(@agent)
    get :dial_check, { :phone_number => "+8558754693849" , :is_country => "true"} 
    result = JSON.parse(response.body).symbolize_keys
    result.should include(:status => "dial_restricted_country") 
  end

  it "must throw exception if country is not present" do
    log_in(@agent)
    get :dial_check, { :phone_number => "+2478754693849" , :is_country => "true"} 
    begin
      expect(response).to raise_error
    rescue Exception => e
    end
  end

  it 'should apply indian number fix for incorrect caller id' do
    create_freshfone_call
    modified_params = incoming_params.merge('caller_sid' => @freshfone_call.id) 
    modified_params["From"] = "+166174802401"
    set_twilio_signature('freshfone/voice', modified_params.except('caller_sid'))
    post :voice, modified_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

  it 'should add a call note to an existing ticket' do
    request.env["HTTP_ACCEPT"] = "application/javascript"
    log_in(@agent)
    ticket = create_ticket({:status => 2})
    freshfone_call = create_freshfone_call
    create_freshfone_user if @agent.freshfone_user.blank?
    params = { :id => ticket.id, :ticket => ticket.display_id, :call_log => "Sample freshfone note", 
               :CallSid => freshfone_call.call_sid, :private => false, :call_history => "false" }
    post :create_note, params
    assigns[:current_call].note.notable.id.should be_eql(ticket.id) 
    assigns[:current_call].note.body.should =~ /Sample freshfone note/
  end

  it 'should create a new call ticket' do
    request.env["HTTP_ACCEPT"] = "application/javascript"
    log_in(@agent)
    freshfone_call = create_freshfone_call
    build_freshfone_caller
    create_freshfone_user if @agent.freshfone_user.blank?
    customer = create_dummy_customer
    params = { :CallSid => freshfone_call.call_sid, :call_log => "Sample Freshfone Ticket", 
               :custom_requester_id => customer.id, :ticket_subject => "Call with Oberyn", :call_history => "false"}
    post :create_ticket, params
    assigns[:current_call].ticket.subject.should be_eql("Call with Oberyn")
  end

  it 'should not add a call note to an existing ticket on failed ticket creation' do
    log_in(@agent)
    ticket = create_ticket({:status => 2})
    freshfone_call = create_freshfone_call
    create_freshfone_user if @agent.freshfone_user.blank?
    params = { :id => ticket.id, :ticket => ticket.display_id, :call_log => "Sample freshfone note", 
               :CallSid => freshfone_call.call_sid, :private => false, :call_history => "false" }
    
    save_note = mock()
    save_note.stubs(:save).returns(false)
    controller.stubs(:build_note).returns(save_note)

    post :create_note, params
    Freshfone::Call.find(freshfone_call.id).note.should be_nil
  end

  it 'should not create a new call ticket on failed ticket creation' do
    request.env["HTTP_ACCEPT"] = "application/javascript"
    log_in(@agent)
    freshfone_call = create_freshfone_call
    build_freshfone_caller
    create_freshfone_user if @agent.freshfone_user.blank?
    customer = create_dummy_customer
    params = { :CallSid => freshfone_call.call_sid, :call_log => "Sample Freshfone Ticket", 
               :custom_requester_id => customer.id, :ticket_subject => "Call with Oberyn", :call_history => "false"}
    
    save_ticket = mock()
    save_ticket.stubs(:save).returns(false)
    controller.stubs(:build_ticket).returns(save_ticket)

    post :create_ticket, params
    Freshfone::Call.find(freshfone_call.id).ticket.should be_nil
  end

  it 'should create a new call ticket with new customer name accordingly when the call is from Strange Number' do
    strange_number = "+17378742833"  
    log_in(@agent)
    freshfone_call = create_freshfone_call
    build_freshfone_caller(strange_number)
    create_freshfone_user if @agent.freshfone_user.blank?
    params = { :CallSid => freshfone_call.call_sid, :call_log => "Sample Freshfone Ticket", 
               :requester_name => strange_number, :ticket_subject => "Call with Oberyn", :call_history => "false"}
    post :create_ticket, params    
    assigns[:current_call].ticket.requester_name.should be_eql("RESTRICTED")
    User.last.name.should be_eql("RESTRICTED")
  end
 
  it 'should go to conference incoming call when conference feature is enabled' do
    log_in @agent
    create_online_freshfone_user
    create_freshfone_call.update_column(:call_status, Freshfone::Call::CALL_STATUS_HASH[:connecting])
    create_call_meta
    create_pinged_agents(true)
    params = incoming_params.merge({'caller_sid' => @freshfone_call.id, 'leg_type' => 'connect'})
    set_twilio_signature("freshfone/voice?caller_sid=#{@freshfone_call.id}&leg_type=connect", params.except(*%w(caller_sid leg_type)))
    post :voice, params 
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
  end

  it 'should give empty response when an exception occurs while an incoming conference call' do
    log_in @agent
    create_online_freshfone_user
    create_freshfone_call
    create_call_meta
    create_pinged_agents(true)
    params = incoming_params.merge({'caller_sid' => @freshfone_call.id, 'leg_type' => 'connect'})
    Freshfone::Notifier.any_instance.stubs(:disconnect_other_agents).raises(StandardError)
    set_twilio_signature("freshfone/voice?caller_sid=#{@freshfone_call.id}&leg_type=connect", params.except(*%w(caller_sid leg_type)))
    post :voice, params 
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Notifier.any_instance.unstub(:disconnect_other_agents)
  end

  it 'should disconnect the agent from conference call is completed' do
    log_in @agent
    create_online_freshfone_user
    create_freshfone_call
    create_call_meta
    create_pinged_agents(true)
    params = incoming_params.merge({'caller_sid' => @freshfone_call.id, 'CallStatus' => 'completed', 'leg_type' => 'disconnect' })
    set_twilio_signature("freshfone/voice?caller_sid=#{@freshfone_call.id}&leg_type=disconnect", params.except(*%w(caller_sid leg_type)))
    post :voice, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
  end

  it 'should initiate voicemail if the intended agent is not answering the conference call' do
    log_in @agent
    create_online_freshfone_user
    create_freshfone_call
    create_call_meta
    create_pinged_agents(false)
    stub_twilio_call(:get, [:update])
    (@account.freshfone_subaccount.calls.get).expects(:update).once
    params = incoming_params.merge({'caller_sid' => @freshfone_call.id, 'CallDuration' => '20',
      'CallStatus' => 'no-answer','leg_type' => 'disconnect' })
    set_twilio_signature("freshfone/voice?caller_sid=#{@freshfone_call.id}&leg_type=disconnect", params.except(*%w(caller_sid leg_type)))
    post :voice, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
  end

  it 'should reconnect to the old call when the agent or group is not answering the transferred conference call' do
    log_in @agent
    create_online_freshfone_user
    create_call_family
    create_call_meta(@parent_call.children.first)
    create_pinged_agents(false, @parent_call.children.first)
    params = incoming_params.merge({'caller_sid' => @parent_call.children.first.id,
      'CallStatus' => 'no-answer','CallDuration' => '20',
      'leg_type' => 'disconnect','external_transfer' => 'true' })
    set_twilio_signature("freshfone/voice?caller_sid#{@parent_call.children.first.id}&leg_type=disconnect&external_transfer=true",
      params.except(*%w(caller_sid leg_type external_transfer)))
    post :voice, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
  end

  it 'should handle simultaneous call on agent leg of incoming when conference feature is enabled' do
    log_in @agent
    create_online_freshfone_user
    create_freshfone_call
    @freshfone_call.update_attributes(:call_status => Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    params = incoming_params.merge('caller_sid' => @freshfone_call.id)
    set_twilio_signature("freshfone/voice?caller_sid=#{@freshfone_call.id}", params.except('caller_sid'))
    post :voice, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Say)
  end

  it 'should go to the conference ivr`s group flow when conference feature is enabled when digits pressed is for group' do
    log_in @agent
    create_freshfone_call
    group = create_group @account, { :name => 'Freshfone Group' }
    AgentGroup.new(:user_id => @agent.id,
      :account_id => @account.id,
      :group_id => group.id).save!

    create_freshfone_user(Freshfone::User::PRESENCE[:online])
    @account.ivrs.create({:freshfone_number_id=>1})
    create_ivr_call_option(group.id)

    Freshfone::Ivr.any_instance.stubs(:params).returns(ivr_flow_params.merge(:Digits => '1', :menu_id => '0'))
    Freshfone::Menu.any_instance.stubs(:ivr).returns(@account.ivrs.first)
    Freshfone::Option.any_instance.stubs(:menu).returns(@account.ivrs.first.ivr_data['0'])

    set_twilio_signature("freshfone/ivr_flow/?menu_id=0", ivr_flow_params.except('menu_id'))
    post :ivr_flow, ivr_flow_params.merge('Digits' => '1', 'menu_id' => '0')
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
    expect(Freshfone::CallMeta.find_by_call_id(@freshfone_call.id).hunt_type).to eq(Freshfone::CallMeta::HUNT_TYPE[:group])
    Freshfone::Option.any_instance.unstub(:menu)
    Freshfone::Menu.any_instance.unstub(:ivr)
    Freshfone::Ivr.any_instance.unstub(:params)
  end


  it 'should go to conference outgoing call when conference feature is enabled' do
  	log_in @agent
  	modified_params = incoming_params.merge(
      'type' => 'outgoing', 'agent' => "#{@agent.id}",
      'PhoneNumber' => '+16617480240')
  	set_twilio_signature('freshfone/voice', modified_params)
  	post :voice, modified_params
  	expect(xml).to be_truthy
  	expect(xml).to have_key(:Response)
  	expect(xml[:Response]).to have_key(:Dial)
  	expect(xml[:Response][:Dial]).to have_key(:Conference)
  end

  it 'should go to conference transfer call when conference is initiated' do
    log_in @agent
  	create_call_family
    @parent_call.update_attributes!({ :conference_sid => 'ConSid',:call_status => Freshfone::Call::CALL_STATUS_HASH[:'on-hold'] })
  	modified_params = incoming_params
  	modified_params.merge!(
      'type' => 'transfer',
      'call' => @parent_call.id,
      'CallSid' => @parent_call.call_sid,
      'child_sid' => 'CA1d4ae9fae956528fdf5e61a64084f191')
  	stub_twilio_queues
  	set_twilio_signature('freshfone/voice', modified_params)
    post :voice, modified_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
    Twilio::REST::Queues.any_instance.unstub(:get)
  end

  it 'should go to conference record when conference is initiated' do
    log_in @agent
    create_freshfone_call
    modified_params = incoming_params.merge('record' => 'true', 'type' => 'record', 'agent' => @agent.id, 'number_id' => @number.id)
    set_twilio_signature('freshfone/voice', modified_params)
    post :voice, modified_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Record)
  end

  it 'should go to the conference ivr`s agent flow when conference feature is enabled and digits pressed for calling agent' do
    log_in @agent
    create_freshfone_call
    group = create_group @account, { :name => 'Freshfone Group' }
    AgentGroup.new(:user_id => @agent.id,
      :account_id => @account.id,
      :group_id => group.id).save!

    create_freshfone_user(Freshfone::User::PRESENCE[:online])
    @account.ivrs.create({:freshfone_number_id=>1})
    create_ivr_call_option(group.id)

    Freshfone::Ivr.any_instance.stubs(:params).returns(ivr_flow_params.merge(:Digits => '2', :menu_id => '0'))
    Freshfone::Menu.any_instance.stubs(:ivr).returns(@account.ivrs.first)
    Freshfone::Option.any_instance.stubs(:menu).returns(@account.ivrs.first.ivr_data['0'])

    set_twilio_signature("freshfone/ivr_flow/?menu_id=0", ivr_flow_params.except('menu_id').merge('Digits' => '2'))
    post :ivr_flow, ivr_flow_params.merge('Digits' => '2', 'menu_id' => '0')
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
    expect(Freshfone::CallMeta.find_by_call_id(@freshfone_call.id).hunt_type).to eq(Freshfone::CallMeta::HUNT_TYPE[:agent])
    Freshfone::Option.any_instance.unstub(:menu)
    Freshfone::Menu.any_instance.unstub(:ivr)
    Freshfone::Ivr.any_instance.unstub(:params)
  end

  it 'should go to the conference ivr`s number flow when conference feature is enabled and digits pressed for calling a number' do
    log_in @agent
    create_freshfone_call
    group = create_group @account, { :name => 'Freshfone Group' }
    AgentGroup.new(:user_id => @agent.id,
      :account_id => @account.id,
      :group_id => group.id).save!

    create_freshfone_user(Freshfone::User::PRESENCE[:online])
    @account.ivrs.create({:freshfone_number_id=>1})
    create_ivr_call_option(group.id)

    Freshfone::Ivr.any_instance.stubs(:params).returns(ivr_flow_params.merge(:Digits => '3', :menu_id => '0'))
    Freshfone::Menu.any_instance.stubs(:ivr).returns(@account.ivrs.first)
    Freshfone::Option.any_instance.stubs(:menu).returns(@account.ivrs.first.ivr_data['0'])

    set_twilio_signature("freshfone/ivr_flow/?menu_id=0", ivr_flow_params.except('menu_id').merge('Digits' => '3'))
    post :ivr_flow, ivr_flow_params.merge('Digits' => '3', 'menu_id' => '0')
    expect(xml).to be_truthy
    expect(xml[:Response]).to be_truthy
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
    Freshfone::Option.any_instance.unstub(:menu)
    Freshfone::Menu.any_instance.unstub(:ivr)
    Freshfone::Ivr.any_instance.unstub(:params)
  end

  it 'should not allow any params which are not acceptable' do
    params = { :call_detail => 'unacceptable' }
    set_twilio_signature('freshfone/ivr_flow', {})
    post :ivr_flow, params
    expect(response.status).to eq(200)
    expect(response.body).to eq(' ')
  end

end