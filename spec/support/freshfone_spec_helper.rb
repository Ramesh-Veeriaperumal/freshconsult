module FreshfoneSpecHelper

  def create_test_freshfone_account
    Freshfone::Account.any_instance.stubs(:close)
    Freshfone::Account.any_instance.stubs(:update_twilio_subaccount_state).returns(true)
    Twilio::REST::IncomingPhoneNumber.any_instance.stubs(:delete).returns(true)
    HTTParty.stubs(:post)
    freshfone_account = Freshfone::Account.new( 
      :twilio_subaccount_id => "AC9fa514fa8c52a3863a76e2d76efa2b8e", 
      :twilio_subaccount_token => "58aacda85de70e5cf4f0ba4ea50d78ab", 
      :twilio_application_id => "AP932260611f4e4830af04e4e3fed66276", 
      :queue => "QU81f8b9ad56f44a62a3f6ef69adc4d7c7",
      :account_id => @account.id, 
      :friendly_name => "RSpec Test",
      :triggers => Freshfone::Account::TRIGGER_LEVELS_HASH.clone )
    freshfone_account.sneaky_save
    @account.freshfone_account = freshfone_account
    create_freshfone_credit
    create_freshfone_number
    @account.features.freshfone.create
    @account.features.freshfone_conference.create
    @account.reload
  end

  def create_freshfone_credit
    @credit = @account.freshfone_credit
    if @credit.present?
      @credit.account = @account
      @credit.update_attributes(:available_credit => 25)
    else
      @credit = @account.create_freshfone_credit(:available_credit => 25)
    end
    @credit.account = @account
  end

  def create_freshfone_number
    if @account.freshfone_numbers.blank?
      @number ||= @account.freshfone_numbers.create( :number => "+12407433321", 
        :display_number => "+12407433321", 
        :country => "US", 
        :region => "Texas", 
        :voicemail_active => true,
        :number_type => 1,
        :state => 1,
        :deleted => false,
        :skip_in_twilio => true,
        :max_queue_length => 3 )
    else
      @number ||= @account.freshfone_numbers.first
    end
  end

  def create_freshfone_caller
    @caller = @account.freshfone_callers.create(:number => "+1234567890",
              :country => "US", 
              :caller_type => 0 )
  end

  def create_freshfone_call(call_sid = "CA2db76c748cb6f081853f80dace462a04", call_type = Freshfone::Call::CALL_TYPE_HASH[:incoming],
                            call_status = Freshfone::Call::CALL_STATUS_HASH[:default])
    @freshfone_call = @account.freshfone_calls.new(:freshfone_number_id => @number.id, 
                                      :call_status => call_status, :call_type => call_type, :agent => @agent,
                                      :params => { :CallSid => call_sid })
    @freshfone_call.account.features.reload
    @freshfone_call.save!
    @freshfone_call
  end

  def create_freshfone_call_meta(call,external_number)
    @call_meta = call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
              :meta_info => {:agent_info => external_number}, :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer])
  end

  def create_supervisor_call(call=@freshfone_call, call_status = Freshfone::SupervisorControl::CALL_STATUS_HASH[:default])
    @supervisor_control= call.supervisor_controls.create(:account_id => @account.id,
         :supervisor_id => @agent.id,
         :supervisor_control_type => Freshfone::SupervisorControl::CALL_TYPE_HASH[:monitoring],
         :supervisor_control_status => call_status,
         :sid => "SCALL")
  end

  def create_freshfone_customer_call(call_sid = "CA2db76c748cb6f081853f80dace462a04")
    user = create_customer
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => call_sid }, :customer => user)
  end

  def build_freshfone_caller(number = "+12345678900")
    account = @freshfone_call.account
    caller  = @account.freshfone_callers.find_or_initialize_by_number(number)
    caller.update_attributes({:number => number})
    @freshfone_call.update_attributes(:caller => caller)
  end

  def create_freshfone_user(presence = 0, agent = @agent)
    # @freshfone_user = @agent.build_freshfone_user({ :account => @account, :presence => presence })
    @freshfone_user = Freshfone::User.find_by_user_id(agent.id)
    if @freshfone_user.blank?
      @freshfone_user = Freshfone::User.create({ :account => @account, :presence => presence, :user => agent })
    end
  end

  def create_agent_conference_call(agent, status = Freshfone::SupervisorControl::CALL_STATUS_HASH[:default], call_sid = 'AGENTCONFCALL')
    @agent_conference_call = @freshfone_call.supervisor_controls.create( supervisor: @account.users.find(agent),
        supervisor_control_type: Freshfone::SupervisorControl::CALL_TYPE_HASH[:agent_conference],
        sid: call_sid,
        supervisor_control_status: status)
  end

  def create_online_freshfone_user
    create_freshfone_user
    @freshfone_user.update_attributes(:presence => 1)
  end

  def create_call_family
    @parent_call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
      :call_status => 0, :call_type => 1, :agent => @agent,
      :params => { :CallSid => "CABCDEFGHIJK" } )
    @parent_call.build_child_call({ :agent => @agent, 
        :CallSid => "CA1d4ae9fae956528fdf5e61a64084f191", 
        :From => "+16617480240"}).save
    @parent_call.root.increment(:children_count).save
  end

  def create_dummy_freshfone_users(n=3,presence=nil)
    @dummy_users = []; @dummy_freshfone_users = []
    n.times do 
      new_agent = add_agent_to_account(@account, {:available => 1, :name => Faker::Name.name, :email => Faker::Internet.email, :role => 3, :active => 1})
      user = new_agent.user
      freshfone_user = user.build_freshfone_user({ :account => @account, :presence => presence || 1})
      user.save!
      user.reload
      @dummy_freshfone_users << freshfone_user
      @dummy_users << user
    end
    @account.users << @dummy_users
  end

  def create_customer
    customer = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email, :user_role => 3)
    customer.save
    customer
  end

  def create_freshfone_outgoing_caller(number = "+1234567890", number_sid = "PN2ba4c66ed6a57e8311eb0f14d5aa2d88")
    @outgoing_caller = @account.freshfone_caller_id.create({:number => number,
                                                        :number_sid => number_sid })
  end

  def set_twilio_signature(path, params = {}, master=false)
    @request.env['HTTP_X_TWILIO_SIGNATURE'] = build_signature_for(path, params, master)
    controller.request.stubs(:url).returns @url
  end

  def build_signature_for(path, params, master)
    auth_token = master ? FreshfoneConfig['twilio']['auth_token'] : @account.freshfone_account.token
    @url = "http://play.ngrok.com/#{path}"
    data = @url + params.sort.join
    digest = OpenSSL::Digest.new('sha1')
    Base64.encode64(OpenSSL::HMAC.digest(digest, auth_token, data)).strip
  end

  def incoming_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "ToZip"=>"79097", "FromState"=>"CA", 
      "Called"=>"+12407433321", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"79097", 
      "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", 
      "CallSid"=>"CA2db76c748cb6f081853f80dace462a04", "CalledState"=>"TX", "From"=>"+16617480240", 
      "CallerZip"=>"93307", "FromZip"=>"93307", "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", 
      "CallStatus"=>"ringing", "ToCity"=>"WHITE DEER", "ToState"=>"TX", "To"=>"+12407433321", "ToCountry"=>"US", 
      "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"WHITE DEER" }
  end

  def supervisor_params
    { :AccountSid =>"AC626dc6e5b03904e6270f353f4a2f068f",
      :Direction =>"inbound", 
      :ApplicationSid =>"APca64694c6df44b0bbcfb34058c567555",
      :CallSid =>"SCALL", 
      :CallStatus =>"ringing", 
      :type => "supervisor",
      :From => "client:1",
      :agent => @agent.id,
      :call => @freshfone_call.id
    }
  end

  def outgoing_params
    { :AccountSid =>"AC626dc6e5b03904e6270f353f4a2f068f",
      :Direction =>"inbound", 
      :ApplicationSid =>"APca64694c6df44b0bbcfb34058c567555",
      :CallSid =>"SCALL", 
      :CallStatus =>"ringing", 
      :From => "client:1",
      :type => "outgoing",
      :agent => @agent.id
    }
  end

  def sip_params
    { :AccountSid =>"AC626dc6e5b03904e6270f353f4a2f068f",
      :Direction =>"inbound", 
      :ApplicationSid =>"APca64694c6df44b0bbcfb34058c567555",
      :CallSid =>"SCALL", 
      :CallStatus =>"ringing", 
      :From => "sip:1",
      :type => "sip",
      :agent => @agent.id
    }
  end

  def supervisor_call_status_params 
    { "CallSid"=>"SCALL",
      "ConferenceSid"=>"ConSid",
      "DialCallSid"=>"DiCalSid",
      "RecordingUrl"=>"",
      "DialCallDuration"=>"6",
      "From"=>"client:1",
      "CallDuration"=>"6"
    }
  end

  def ivr_flow_params
    {"AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "ToZip"=>"79097", "FromState"=>"CA", 
      "Called"=>"+12407433321", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"79097", 
      "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", 
      "CallSid"=>"CA2db76c748cb6f081853f80dace462a04", "CalledState"=>"TX", "From"=>"+16617480240", 
      "CallerZip"=>"93307", "FromZip"=>"93307", "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", 
      "CallStatus"=>"in-progress", "ToCity"=>"WHITE DEER", "ToState"=>"TX", "To"=>"+12407433321", "Digits"=>"1", 
      "ToCountry"=>"US", "msg"=>"Gather End", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", 
      "Caller"=>"+16617480240", "CalledCity"=>"WHITE DEER", "menu_id"=>"0"}
  end

  def agent_call_leg_params
    {"ApiVersion"=>"2010-04-01", "Called"=>"client:1", :CallStatus => "busy", "Duration"=>"0","From"=>"+16463928103", 
    "Direction"=>"outbound-api",:CallDuration => "0", "Timestamp"=>"Wed, 06 Jan 2016 06:47:56 +0000", "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", 
    "CallbackSource"=>"call-progress-events", "SipResponseCode"=>"[FILTERED]", "Caller"=>"+16463928103", "SequenceNumber"=>"0", 
    :CallSid => "CA2db76c748cb6f081853f80dace462a04", "To"=>"client:1", 
    :agent_id => "1", "leg_type"=>"disconnect"}
  end

  def fallback_params
    { "ErrorUrl"=>"http://myk0.t.proxylocal.com/telephony/call/status", "ErrorCode"=>"11205" }
  end

  def voicemail_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "ToZip"=>"79097", "FromState"=>"CA", 
      "Called"=>"+12407433321", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"79097", 
      "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", 
      "CallSid"=>"CA2db76c748cb6f081853f80dace462a04", "CalledState"=>"TX", "From"=>"+16617480240", 
      "CallerZip"=>"93307", "FromZip"=>"93307", "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", 
      "CallStatus"=>"completed", "ToCity"=>"WHITE DEER", "ToState"=>"TX", 
      "RecordingUrl"=>"http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b", 
      "To"=>"+12407433321", "Digits"=>"hangup", "ToCountry"=>"US", "RecordingDuration"=>"5", 
      "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"WHITE DEER", 
      "RecordingSid"=>"REa618f1f9d5cbf4117cb4121bc2aa5a0b"}

  end

  def record_params
    { "RecordingUrl" => "http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b",
      "agent" => @agent.id,
      "number_id" => @number.id }
  end

  def twimlify(body)
    twiml = Hash.from_trusted_xml body
    twiml.deep_symbolize_keys if twiml.present?
  end

  def create_ff_address(post_code = Faker::Address.postcode)
    name = Faker::Name.name
    address_params = { :id => 1, :friendly_name => name, :business_name => name, :address => Faker::Address.street_address,
        :city => Faker::Address.city, :state => Faker::Address.state, :postal_code => post_code,
        :country => 'DE'
    }
    @account.freshfone_account.freshfone_addresses.new(address_params).save
  end

  def ff_address_inspect(country)
    @account.freshfone_account.freshfone_addresses.find_by_country(country).present?
  end
  
  def accessible_groups(number)
    groups = []
    selected_number_group = number.freshfone_number_groups
    if selected_number_group
      selected_number_group.each do |number_group|
        groups << number_group.group_id
      end
    end
    groups
  end
  
  def conference_call_params
    {:CallSid => (@freshfone_call || @parent_call).call_sid,
      :ConferenceSid => 'ConSid',
      :DialCallSid => 'DiCalSid',
      :RecordingUrl => 'https://xyz.freshdesk.com/123.mp3',
      :DialCallDuration => '6'
    }
  end

  def create_call_meta(call = @freshfone_call)
    @freshfone_call_meta = call.create_meta(:account => @account)
  end

  def create_ivr_call_option(group_id = 0)
  	@account.ivrs.first.update_attributes(:ivr_data =>
			{ '0' => create_ivr_menu(group_id) })
  end

  def create_ivr_menu(group_id)
    Freshfone::Menu.new(
      { 'menu_name' => 'Welcome/Start Menu',
        'menu_id' => '0',
        'message_type' => '2',
        'recording_url' => '',
        'attachment_id' => '',
        'message' => 'Press 1 For Group, 2 For Agent & 3 For Direct Dial',
        'options' => option_params(group_id, '0') })
  end

	def option_params(group_id, menu_id)
  	[Freshfone::Option.new({ 'respond_to_key' => '1', 'performer' => :Group, 'performer_id' => "#{group_id}", 'performer_number' => '', 'menu' => menu_id }),
			Freshfone::Option.new({ 'respond_to_key' => '2', 'performer' => :User, 'performer_id' => "#{@agent.id}", 'performer_number' => '', 'menu' => menu_id }),
			Freshfone::Option.new({ 'respond_to_key' => '3', 'performer' => :Number, 'performer_id' => '', 'performer_number' => '+919999999999','menu' => menu_id })
		]
	end

  def stub_twilio_queues(empty_queue = false)
    queues = mock
    members = mock
    member = mock
    member.stubs(:dequeue)
    member.stubs(:update)
    current_size = empty_queue ? 0 : 1
    queues.stubs(:current_size).returns(current_size)
    members.stubs(:get).returns(member)
    members.stubs(:list).returns([member])
    queues.stubs(:members).returns(members)
    Twilio::REST::Queues.any_instance.stubs(:get).returns(queues)
  end

  def forward_complete_params
    {
      'Called'=>'+12407433321', 'ToState'=>'TX', 'CallerCountry'=>'US', 'Direction'=>'outbound-api', 'Timestamp'=>'Tue, 07 Jul 2015 12:01:53 +0000',
      'CallbackSource'=>'call-progress-events', 'CallerState'=>'NV', 'ToZip'=>'77521', 'SequenceNumber'=>'0',
      'To'=>'+12407433321', 'CallerZip'=>'89016', 'ToCountry'=>'US', 'CalledZip'=>'77521', 'ApiVersion'=>'2010-04-01',
      'CallStatus'=>'completed', 'CalledCity'=>'BAYTOWN', 'From'=>'+16617480240', 'AccountSid'=>'AC626dc6e5b03904e6270f353f4a2f068f',
      'CalledCountry'=>'US', 'CallerCity'=>'SEARCHLIGHT', 'FromCountry'=>'US', 'ToCity'=>'BAYTOWN', 'Caller'=>'+16617480240',
      'FromCity'=>'SEARCHLIGHT', 'CalledState'=>'TX', 'FromZip'=>'89016', 'FromState'=>'NV'
    }
  end

  def create_pinged_agents(accepted = false, call = @freshfone_call)
    agent_response = accepted ? :accepted : :'no-answer'
    @freshfone_call_meta.update_attributes!( {:pinged_agents => [{
      :id => @agent.id,
      :name => @agent.name,
      :call_sid => call.call_sid,
      :response => Freshfone::CallMeta::PINGED_AGENT_RESPONSE_HASH[agent_response]
      }] } )
  end

  def stub_twilio_call(twilio_meth, mock_meths)
    twilio_call = mock
    mock_meths.each do |meth|
      twilio_call.stubs(meth)
    end
    Twilio::REST::Calls.any_instance.stubs(twilio_meth).returns(twilio_call)
    twilio_call
  end

  def completed_outgoing_conference_call
    build_freshfone_caller
    @freshfone_call.dial_call_sid = 'DDSid'
    @freshfone_call.call_sid = 'CalSid'
    @freshfone_call.total_duration = CALL_DURATION
    @freshfone_call.call_type = Freshfone::Call::CALL_TYPE_HASH[:outgoing]
    @freshfone_call.sneaky_save
    @freshfone_call.caller.update_column(:country, 'US')
  end

  def freshfone_call_without_conference
    @account.features.freshfone_conference.delete if @account.features?(:freshfone_conference)
    @account.reload
    @freshfone_call.dial_call_sid = 'DDSid'
    @freshfone_call.sneaky_save
  end
  
  def create_test_freshfone_subscription(options = {})
    @freshfone_subscription = Freshfone::Subscription.create(
      account: @account,
      freshfone_account: @account.freshfone_account,
      inbound: Freshfone::Subscription::INBOUND_HASH.except(:trigger),
      outbound: Freshfone::Subscription::OUTBOUND_HASH.except(:trigger),
      numbers: Freshfone::Subscription::NUMBERS_HASH.merge(credit: options[:number_credit], count: options[:number_count]),
      calls_usage: Freshfone::Subscription::DEFAULT_CALLS_USAGE_HASH,
      expiry_on: 15.days.from_now)
  end

  def load_freshfone_trial(create_options={})
    create_test_freshfone_subscription(create_options)
    @account.freshfone_account.update_column(:state, Freshfone::Account::STATE_HASH[:trial])
  end

  def get_pinged_agent(agent_id, call = @freshfone_call)
    call.meta.reload
    call.meta.pinged_agents.each do |agent|
      return agent if agent[:id] == agent_id
    end
  end

  def update_ringing_at_in_pinged_agents(agent_id, call = @freshfone_call)
    call.meta.reload
    call.meta.update_pinged_agent_ringing_at(agent_id)
  end

  def twilio_mock_helper(sid, current_value, trigger_value)
    twilio_trigger = mock
    twilio_trigger.stubs(:sid).returns(sid)
    twilio_trigger.stubs(:current_value).returns(current_value)
    twilio_trigger.stubs(:trigger_value).returns(trigger_value)
    Twilio::REST::Triggers.any_instance.stubs(:create).returns(twilio_trigger)
  end

end