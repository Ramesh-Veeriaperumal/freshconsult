module FreshfoneCallSpecHelper
  BATCH_KEY = "FRESHFONE:AGENTS_BATCH:1:CA904f175a4e625a045e3270720dd195dd"
  TRANSFER_KEY = "FRESHFONE:TRANSFERS:1:CA904f175a4e625a045e3270720dd195dd"
  CLIENT_CALL = "FRESHFONE:CLIENT_CALLS:1"
  def setup_caller_data
    Faker::Base.numerify('(###)###-####')
    @number = Faker::PhoneNumber.phone_number
    @agent.update_attributes(:phone => @number)
    Freshfone::Search.stubs(:search_user_with_number).returns(@agent)
    create_call_with_caller_and_meta
  end

  def setup_batch
    create_dummy_freshfone_users
    controller.set_key(BATCH_KEY, @dummy_freshfone_users.map(&:id).to_json)
  end

  def setup_call_for_transfer
    controller.send(:call_action)
    controller.set_key(TRANSFER_KEY, [@agent.id.to_s].to_json)
  end

  def set_active_call_in_redis(additional_params = {})
    key = "FRESHFONE_ACTIVE_CALL:#{@account.id}:CA67b4b4052a6c79d662a27edda3615449"
    controller.set_key(key, {:agent => @agent.id}.merge(additional_params).to_json)
  end

  def tear_down(key)
    controller.remove_key(key)
  end

  def create_call_for_status
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => 1, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => "CA904f175a4e625a045e3270720dd195dd" } )
  end

  def in_call_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+18062791926", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"client:1", "ParentCallSid"=>"CAa908212d5ff226e1ce21670b41b6f6cc", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+18062791926", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CSATH", "From"=>"+16617480240", "CallerZip"=>"93307", 
      "FromZip"=>"93307", "agent"=>"#{@agent.id}"}
  end

  def direct_dial_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CalledVia"=>"+18062791926", "FromState"=>"CA", "ToZip"=>"", 
      "Called"=>"+919994269753", "ParentCallSid"=>"CDIRECTPARENT", "FromCountry"=>"US", 
      "CallerCountry"=>"US", "CalledZip"=>"", "Direction"=>"outbound-dial", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+18062791926", 
      "CalledCountry"=>"IN", "CallerState"=>"CA", "CallSid"=>"CDIRECT", "CalledState"=>"Tamil Nadu", 
      "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", "CallStatus"=>"in-progress", "ToCity"=>"", 
      "ToState"=>"Tamil Nadu", "To"=>"+919994269753", "ToCountry"=>"IN", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", 
      "Caller"=>"+16617480240", "CalledCity"=>"", "direct_dial_number"=>"9994269753"}
  end

  def call_transfer_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+18062791926", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"client:1", "ParentCallSid"=>"CAa908212d5ff226e1ce21670b41b6f6cc", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+18062791926", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CTRANSFER", "From"=>"+16617480240", "CallerZip"=>"93307", 
      "FromZip"=>"93307" }
  end

  def status_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "ToZip"=>"79097", "FromState"=>"CA", "Called"=>"+18062791926", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"79097", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", 
      "CalledCountry"=>"US", "CallerState"=>"CA", "DialCallDuration"=>"6", "CallSid"=>"CA904f175a4e625a045e3270720dd195dd", 
      "CalledState"=>"TX", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", 
      "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", "CallStatus"=>"in-progress", 
      "DialCallSid"=>"CA67b4b4052a6c79d662a27edda3615449", "ToCity"=>"WHITE DEER", "ToState"=>"TX", 
      "RecordingUrl"=>"http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/RE53fbb52943c5f44202005798d62b3e28", 
      "To"=>"+18062791926", "ToCountry"=>"US", "DialCallStatus"=>"completed", "RecordingDuration"=>"3", 
      "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", 
      "CalledCity"=>"WHITE DEER", "RecordingSid"=>"RE53fbb52943c5f44202005798d62b3e28" }
  end

  private
    def create_call_with_caller_and_meta
      call = @account.freshfone_calls.create( :freshfone_number_id => 1, 
               :call_status => 0, :call_type => 1, :agent => @agent,
               :params => { :CallSid => "CA9cdcef5973752a0895f598a3413a88d5", :From => @number } )
      call.create_meta( :account => @account, :group_id => Group.first)
    end

end