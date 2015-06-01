module FreshfoneTransferSpecHelper
  def initiate_params
    { :call_sid => "CA2db76c748cb6f081853f80dace462a04", :outgoing => "false" }
  end

  def incoming_call_transfer_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+12407433321", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"+12407433321", "ParentCallSid"=>"CA2db76c748cb6f081853f80dace462a04", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+12407433321", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CTRANSFER", "From"=>"+16617480240", "CallerZip"=>"93307", 
      "FromZip"=>"93307" }
  end

  def outgoing_call_transfer_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+12407433321", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"", "ParentCallSid"=>"CA2db76c748cb6f081853f80dace462a04", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+12407433321", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CTRANSFER", "From"=>"+12407433321", "CallerZip"=>"93307", 
      "FromZip"=>"93307" }
  end
end