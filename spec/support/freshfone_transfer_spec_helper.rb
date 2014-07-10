module FreshfoneTransferSpecHelper
  def initiate_params
    { :call_sid => "CAb5ce7735068c8cd04a428ed9a57ef64e", :outgoing => "false" }
  end

  def incoming_call_transfer_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+18062791926", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"+18062791926", "ParentCallSid"=>"CAa908212d5ff226e1ce21670b41b6f6cc", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+18062791926", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CTRANSFER", "From"=>"+16617480240", "CallerZip"=>"93307", 
      "FromZip"=>"93307" }
  end

  def outgoing_call_transfer_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "CallStatus"=>"in-progress", "CalledVia"=>"+18062791926", 
      "FromState"=>"CA", "Called"=>"client:1", "To"=>"", "ParentCallSid"=>"CAa908212d5ff226e1ce21670b41b6f6cc", 
      "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-dial", "CallerCity"=>"BAKERSFIELD", 
      "ApiVersion"=>"2010-04-01", "FromCity"=>"BAKERSFIELD", "ForwardedFrom"=>"+18062791926", "Caller"=>"+16617480240", 
      "CallerState"=>"CA", "CallSid"=>"CTRANSFER", "From"=>"+18062791926", "CallerZip"=>"93307", 
      "FromZip"=>"93307" }
  end
end