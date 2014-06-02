module FreshfoneSpecHelper

  def create_test_freshfone_account
    Freshfone::Account.any_instance.stubs(:close)
    Freshfone::Account.any_instance.stubs(:update_twilio_subaccount_state).returns(true)
    freshfone_account = Freshfone::Account.new( 
                          :twilio_subaccount_id => "AC626dc6e5b03904e6270f353f4a2f068f", 
                          :twilio_subaccount_token => "9440b022c423b59a8339715b6e7d4f80", 
                          :twilio_application_id => "APca64694c6df44b0bbcfb34058c567555", 
                          :queue => "QU629430fd5b8d41769b02abfe7bfbe3a9",
                          :account_id => @account.id, 
                          :friendly_name => "RSpec Test" )
    freshfone_account.send(:create_without_callbacks)
    @account.freshfone_account = freshfone_account
    create_freshfone_credit
    create_freshfone_number
    @account.features.freshfone.create
  end

  def create_freshfone_credit
    @credit = @account.freshfone_credit
    if @credit.present?
      @credit.update_attributes(:available_credit => 25)
    else
      @account.create_freshfone_credit(:available_credit => 25)
    end
  end

  def create_freshfone_number
    if @account.freshfone_numbers.blank?
      @number ||= @account.freshfone_numbers.create( :number => "+18062791926", 
                                      :display_number => "+18062791926", 
                                      :country => "US", 
                                      :region => "Texas", 
                                      :voicemail_active => true,
                                      :number_type => 1 )
    else
      @number ||= @account.freshfone_numbers.first
    end
  end

  def create_freshfone_call(call_sid = "CA9cdcef5973752a0895f598a3413a88d5")
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => call_sid } )
  end

  def create_freshfone_user(presence = 0)
    @freshfone_user = @agent.build_freshfone_user({ :account => @account, :presence => presence })
    @freshfone_user.save!
  end

  def create_online_freshfone_user
    create_freshfone_user(1)
  end

  def create_call_family
    @parent_call = @account.freshfone_calls.create( :freshfone_number_id => 1, 
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
      new_agent = Factory.build(  :agent, :signature => "Regards, #{Faker::Name.name}", 
                                  :account_id => @account.id, :available => 1)
      user = Factory.build(:user, :account => @account, :email => Faker::Internet.email, :user_role => 3, :helpdesk_agent => true )
      user.agent = new_agent
      user.roles = [@account.roles.second]
      freshfone_user = user.build_freshfone_user({ :account => @account, :presence => 1 })
      user.save!
      @dummy_freshfone_users << freshfone_user
      @dummy_users << user
    end
    @account.users << @dummy_users
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
      "Called"=>"+18062791926", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"79097", 
      "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", 
      "CallSid"=>"CA9cdcef5973752a0895f598a3413a88d5", "CalledState"=>"TX", "From"=>"+16617480240", 
      "CallerZip"=>"93307", "FromZip"=>"93307", "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", 
      "CallStatus"=>"ringing", "ToCity"=>"WHITE DEER", "ToState"=>"TX", "To"=>"+18062791926", "ToCountry"=>"US", 
      "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"WHITE DEER" }
  end

  def ivr_flow_params
    {"AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "ToZip"=>"79097", "FromState"=>"CA", 
      "Called"=>"+18062791926", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"79097", 
      "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", 
      "CallSid"=>"CA1d4ae9fae956528fdf5e61a64084f191", "CalledState"=>"TX", "From"=>"+16617480240", 
      "CallerZip"=>"93307", "FromZip"=>"93307", "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", 
      "CallStatus"=>"in-progress", "ToCity"=>"WHITE DEER", "ToState"=>"TX", "To"=>"+18062791926", "Digits"=>"1", 
      "ToCountry"=>"US", "msg"=>"Gather End", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", 
      "Caller"=>"+16617480240", "CalledCity"=>"WHITE DEER", "menu_id"=>"0"}
  end

  def fallback_params
    { "ErrorUrl"=>"http://myk0.t.proxylocal.com/telephony/call/status", "ErrorCode"=>"11205" }
  end

  def voicemail_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "ToZip"=>"79097", "FromState"=>"CA", 
      "Called"=>"+18062791926", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"79097", 
      "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", 
      "CallSid"=>"CA9cdcef5973752a0895f598a3413a88d5", "CalledState"=>"TX", "From"=>"+16617480240", 
      "CallerZip"=>"93307", "FromZip"=>"93307", "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", 
      "CallStatus"=>"completed", "ToCity"=>"WHITE DEER", "ToState"=>"TX", 
      "RecordingUrl"=>"http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b", 
      "To"=>"+18062791926", "Digits"=>"hangup", "ToCountry"=>"US", "RecordingDuration"=>"5", 
      "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"WHITE DEER", 
      "RecordingSid"=>"REa618f1f9d5cbf4117cb4121bc2aa5a0b"}

  end

  def record_params
    { "RecordingUrl" => "http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/REa618f1f9d5cbf4117cb4121bc2aa5a0b",
      "agent" => @agent.id,
      "number_id" => 1 }
  end

end