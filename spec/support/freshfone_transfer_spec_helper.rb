module FreshfoneTransferSpecHelper
  def initiate_params
    { :call_sid => "CA2db76c748cb6f081853f80dace462a04", :outgoing => "false" }
  end

  def initiate_external_params(outgoing)
    { :call_sid => "CA2db76c748cb6f081853f80dace462a04", :outgoing => outgoing, :external_number => '%2B919876543210',
       :id => "919876543210", :group_id => "" }
  end

  def incoming_call_transfer_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+12407433321", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"+12407433321", "ParentCallSid"=>"CA2db76c748cb6f081853f80dace462a04", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+12407433321", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CTRANSFER", "From"=>"+16617480240", "CallerZip"=>"93307", 
      "FromZip"=>"93307" }
  end

  def incoming_external_transfer_params
     {"AccountSid"=>"ACdfefab935e1aee7582b5ff0af03c8df8", "ToZip"=>"80204", "FromState"=>"CA", "Called"=>"+12407433321", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"80204", "Direction"=>"inbound", 
      "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", "CallSid"=>"CA6a757c3aa00185dbb941e63acf64e359", 
      "CalledState"=>"CO", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", "CallStatus"=>"in-progress", 
      "ToCity"=>"DENVER", "ToState"=>"CO", "To"=>"+12407433321", "ToCountry"=>"US", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"DENVER"}
  end

  def outgoing_external_transfer_params
    {"AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "ToZip"=>"", "FromState"=>"CO", "Called"=>"+919123456780",
     "ParentCallSid"=>"CA2db76c748cb6f081853f80dace462a04", "FromCountry"=>"US", "CallerCountry"=>"US", 
     "CalledZip"=>"", "Direction"=>"outbound-dial", "FromCity"=>"DENVER", "CalledCountry"=>"IN", "CallerState"=>"CO",
      "CallSid"=>"CTRANSFER", "CalledState"=>"Chennai", "From"=>"+12407433321", 
      "CallerZip"=>"80204", "FromZip"=>"80204", "CallStatus"=>"in-progress", "ToCity"=>"", "ToState"=>"Chennai",
      "To"=>"+919123456780", "ToCountry"=>"IN", "CallerCity"=>"DENVER", "ApiVersion"=>"2010-04-01", 
      "Caller"=>"+16617480240","CalledCity"=>""}
  end

  def outgoing_call_transfer_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+12407433321", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"", "ParentCallSid"=>"CA2db76c748cb6f081853f80dace462a04", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+12407433321", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CA2db76c748cb6f081853f80dace462a04", "From"=>"+12407433321", "CallerZip"=>"93307", 
      "FromZip"=>"93307" }
  end

  def create_external_transfered_call
    call = @account.freshfone_calls.create( :freshfone_number_id => @number.id, 
               :call_status => 1, :call_type => 1, :group_id => Group.first,
               :params => { :CallSid => "CA9cdcef5973752a0895f598a3413a88d5",:ParentCallSid => 'CA2db76c748cb6f081853f80dace462a04',
                :From => @caller_number
                } )
    call.create_meta(  :account_id => @account, :call_id => call.id,
              :transfer_by_agent => @agent.id,
              :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer],
              :meta_info => '+919876543210')
  end

end