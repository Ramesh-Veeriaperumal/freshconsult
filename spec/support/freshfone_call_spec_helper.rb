module FreshfoneCallSpecHelper
  BATCH_KEY = "FRESHFONE:AGENTS_BATCH:1:CA2db76c748cb6f081853f80dace462a04"
  TRANSFER_KEY = "FRESHFONE:TRANSFERS:1:CA2db76c748cb6f081853f80dace462a04"
  CLIENT_CALL = "FRESHFONE:CLIENT_CALLS:1"
  def setup_caller_data
    @caller_number = Faker::Base.numerify('(###)###-####')
    @agent.update_attributes(:phone => @caller_number)
    Freshfone::Search.stubs(:search_user_with_number).returns(@agent)
    create_call_with_caller_and_meta
  end

  def setup_batch
    create_dummy_freshfone_users
    controller.set_key(BATCH_KEY, @dummy_freshfone_users.map(&:id).to_json)
  end

  def setup_call_for_transfer
    # controller.send(:call_action)
    controller.set_key(TRANSFER_KEY, [@agent.id.to_s].to_json)
  end

  def set_active_call_in_redis(additional_params = {})
    key = "FRESHFONE_ACTIVE_CALL:#{@account.id}:CA2db76c748cb6f081853f80dace462a04"
    controller.set_key(key, {:agent => @agent.id}.merge(additional_params).to_json)
  end

  def tear_down(key)
    controller.remove_key(key)
  end

  def create_call_for_status
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 1, :agent => @agent,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" } )
  end

  def in_call_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+12407433321", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"client:1", "ParentCallSid"=>"CA2db76c748cb6f081853f80dace462a04", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+12407433321", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CSATH", "From"=>"+16617480240", "CallerZip"=>"93307", 
      "FromZip"=>"93307", "agent"=>"#{@agent.id}"}
  end

  def direct_dial_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CalledVia"=>"+12407433321", "FromState"=>"CA", "ToZip"=>"", 
      "Called"=>"+919994269753", "ParentCallSid"=>"CDIRECTPARENT", "FromCountry"=>"US", 
      "CallerCountry"=>"US", "CalledZip"=>"", "Direction"=>"outbound-dial", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+12407433321", 
      "CalledCountry"=>"IN", "CallerState"=>"CA", "CallSid"=>"CDIRECT", "CalledState"=>"Tamil Nadu", 
      "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", "CallStatus"=>"in-progress", "ToCity"=>"", 
      "ToState"=>"Tamil Nadu", "To"=>"+919994269753", "ToCountry"=>"IN", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", 
      "Caller"=>"+16617480240", "CalledCity"=>"", "direct_dial_number"=>"9994269753"}
  end

  def call_transfer_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+12407433321", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"client:1", "ParentCallSid"=>"CA2db76c748cb6f081853f80dace462a04", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+12407433321", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CTRANSFER", "From"=>"+16617480240", "CallerZip"=>"93307", 
      "FromZip"=>"93307" }
  end

  def status_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "ToZip"=>"79097", "FromState"=>"CA", "Called"=>"+12407433321", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"79097", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", 
      "CalledCountry"=>"US", "CallerState"=>"CA", "DialCallDuration"=>"6", "CallSid"=>"CA2db76c748cb6f081853f80dace462a04", 
      "CalledState"=>"TX", "From"=>"+12407433321", "CallerZip"=>"93307", "FromZip"=>"93307", 
      "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", "CallStatus"=>"in-progress", 
      "DialCallSid"=>"CA2db76c748cb6f081853f80dace462a04", "ToCity"=>"WHITE DEER", "ToState"=>"TX", 
      "RecordingUrl"=>"http://api.twilio.com/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Recordings/RE53fbb52943c5f44202005798d62b3e28", 
      "To"=>"+12407433321", "ToCountry"=>"US", "DialCallStatus"=>"completed", "RecordingDuration"=>"3", 
      "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+12407433321", 
      "CalledCity"=>"WHITE DEER", "RecordingSid"=>"RE53fbb52943c5f44202005798d62b3e28" }
  end

  private
    def create_call_with_caller_and_meta
      call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
               :call_status => 0, :call_type => 1, :agent => @agent, :group_id => Group.first,
               :params => { :CallSid => "CA9cdcef5973752a0895f598a3413a88d5", :From => @caller_number
                } )#group_id moved from meta to freshfone_calls. 
    end

end