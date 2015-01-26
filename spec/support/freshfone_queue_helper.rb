module FreshfoneQueueHelper

  def queue_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "QueueSid"=>"QU629430fd5b8d41769b02abfe7bfbe3a9", 
      "CurrentQueueSize"=>"1", "ToZip"=>"79097", "FromState"=>"CA", "AvgQueueTime"=>"0", 
      "Called"=>"+12407433321", "FromCountry"=>"US", "CallerCountry"=>"US", 
      "CalledZip"=>"79097", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", 
      "CallerState"=>"CA", "CallSid"=>"CAae09f7f2de39bd201ac9276c6f1cc66a", "QueuePosition"=>"1", 
      "CalledState"=>"TX", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", 
      "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", "CallStatus"=>"in-progress", 
      "ToCity"=>"WHITE DEER", "ToState"=>"TX", "To"=>"+12407433321", "ToCountry"=>"US", 
      "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", 
      "CalledCity"=>"WHITE DEER", "QueueTime"=>"0" }
  end

  def dequeue_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "QueueSid"=>"QU629430fd5b8d41769b02abfe7bfbe3a9", 
      "ToZip"=>"79097", "FromState"=>"CA", "Called"=>"+12407433321", "FromCountry"=>"US", 
      "CallerCountry"=>"US", "CalledZip"=>"79097", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", 
      "CalledCountry"=>"US", "CallerState"=>"CA", "CallSid"=>"CAb5ce7735068c8cd04a428ed9a57ef64e", 
      "CalledState"=>"TX", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", 
      "CallStatus"=>"in-progress", "ToCity"=>"WHITE DEER", "QueueResult"=>"redirected", "ToState"=>"TX", 
      "To"=>"+12407433321", "ToCountry"=>"US", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", 
      "Caller"=>"+16617480240", "CalledCity"=>"WHITE DEER", "QueueTime"=>"39", "Digits"=>"*" }
  end

  def hangup_params
    { "AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "QueueSid"=>"QU629430fd5b8d41769b02abfe7bfbe3a9", 
      "ToZip"=>"79097", "FromState"=>"CA", "Called"=>"+12407433321", "FromCountry"=>"US", 
      "CallerCountry"=>"US", "CalledZip"=>"79097", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", 
      "CalledCountry"=>"US", "CallerState"=>"CA", "CallSid"=>"CDEFAULTQUEUE", 
      "CalledState"=>"TX", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", 
      "ApplicationSid"=>"APca64694c6df44b0bbcfb34058c567555", "CallStatus"=>"in-progress", 
      "ToCity"=>"WHITE DEER", "QueueResult"=>"hangup", "ToState"=>"TX", "To"=>"+12407433321", 
      "ToCountry"=>"US", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", 
      "Caller"=>"+16617480240", "CalledCity"=>"WHITE DEER", "QueueTime"=>"67" }
  end

  def set_default_queue_redis_entry
    controller.set_key(DEFAULT_QUEUE % {account_id: @account.id}, ["CDEFAULTQUEUE"].to_json)
  end

  def set_agent_queue_redis_entry
    controller.set_key(AGENT_QUEUE % {account_id: @account.id}, 
        { @agent.id => ["CAGENTQUEUE"] }.to_json)

  end

  DEFAULT_QUEUE = "FRESHFONE:CALLS:QUEUE:%{account_id}"
  AGENT_QUEUE = "FRESHFONE:AGENT_QUEUE:%{account_id}"
end