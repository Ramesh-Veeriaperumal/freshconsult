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
      :friendly_name => "RSpec Test" )
    freshfone_account.sneaky_save
    @account.freshfone_account = freshfone_account
    create_freshfone_credit
    create_freshfone_number
    @account.features.freshfone.create
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
        :deleted => false )
    else
      @number ||= @account.freshfone_numbers.first
    end
  end

  def create_freshfone_call(call_sid = "CA2db76c748cb6f081853f80dace462a04")
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => call_sid })
  end

  def create_freshfone_call_meta(call,external_number)
    @call_meta = call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
              :meta_info => external_number, :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer])
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

  def create_freshfone_user(presence = 0)
    # @freshfone_user = @agent.build_freshfone_user({ :account => @account, :presence => presence })
    @freshfone_user = Freshfone::User.find_by_user_id(@agent.id)
    if @freshfone_user.blank?
      @freshfone_user = Freshfone::User.create({ :account => @account, :presence => presence, :user => @agent })
    end
  end

  def create_online_freshfone_user
    create_freshfone_user
    @freshfone_user.update_attributes(:presence => 1)
  end

  def create_call_family
    @parent_call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
      :call_status => 0, :call_type => 1,
      :params => { :CallSid => "CABCDEFGHIJK" } )
    @parent_call.build_child_call({ :agent => @agent, 
        :CallSid => "CA1d4ae9fae956528fdf5e61a64084f191", 
        :From => "+16617480240"}).save
    @parent_call.root.increment(:children_count).save
  end

  def create_dummy_freshfone_users(n=3)
    @dummy_users = []; @dummy_freshfone_users = []
    n.times do 
      new_agent = add_agent_to_account(@account, {:available => 1, :name => Faker::Name.name, :email => Faker::Internet.email, :role => 3, :active => 1})
      user = new_agent.user
      freshfone_user = user.build_freshfone_user({ :account => @account, :presence => 1 })
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

  def create_ff_address
    name = Faker::Name.name
    address_params = { :friendly_name => name, :business_name => name, :address => Faker::Address.street_address,
        :city => Faker::Address.city, :state => Faker::Address.state, :postal_code => Faker::Address.postcode,
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
end