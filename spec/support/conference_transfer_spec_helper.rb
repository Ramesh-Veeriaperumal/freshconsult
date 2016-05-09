module ConferenceTransferSpecHelper

  def initiate_transfer_params(group_id = "", outgoing = "false", sid = "CTRANSFER")
     {"CallSid"=> sid, "target"=>"110", "group_id"=>group_id, "outgoing"=>outgoing, "type"=>"normal"}
  end

  def transfer_agent_wait_params
     {"AccountSid"=>"ACdfefab935e1aee7582b5ff0af03c8df8", "Caller"=>"", "CallStatus"=>"in-progress",
      "Called"=>"", "To"=>"", "ConferenceSid"=>"CF2a553c92825fb4d2614de4613cdab862",
      "CallSid"=>"CTRANSFERCHILD", "From"=>"", 
      "Direction"=>"outbound-dial", "ApiVersion"=>"2010-04-01"}
  end

  def transfer_success_params(call_id)
     {"AccountSid"=>"ACdfefab935e1aee7582b5ff0af03c8df8", "CallStatus"=>"in-progress", "FromState"=>"CA", "Called"=>"client:110", "To"=>"client:110", "FromCountry"=>"US", "CallerCountry"=>"US", "Direction"=>"outbound-api", "ApiVersion"=>"2010-04-01", "CallerCity"=>"BAKERSFIELD", "FromCity"=>"BAKERSFIELD", "Caller"=>"+16617480240", "CallerState"=>"CA", 
      "CallSid"=>"CTRANSFERCHILD", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", "call"=>"#{call_id}"}
  end

  def transfer_unhold_params
     {"AccountSid"=>"ACdfefab935e1aee7582b5ff0af03c8df8", "QueueSid"=>"QU89e23e913537870dd08f3c17fad075ef", "ToZip"=>"80204", "FromState"=>"CA", "Called"=>"+17209031774", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"80204", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", "CallSid"=>"CONFCALL", "CalledState"=>"CO", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", "CallStatus"=>"in-progress", "ToCity"=>"DENVER", "QueueResult"=>"redirected", "ToState"=>"CO", "To"=>"+17209031774", "ToCountry"=>"US", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"DENVER", "QueueTime"=>"18"}
  end

  def resume_transfer_params
    {"CallSid"=>"CA830bb339edddb0e83cd7c7ad967d4f0d", "outgoing"=>"false"}
  end

  def hold_wait_params(call_sid = 'CONFCALL')
     {"AccountSid"=>"ACdfefab935e1aee7582b5ff0af03c8df8", "QueueSid"=>"QSID", "CurrentQueueSize"=>"1", "ToZip"=>"80204", "FromState"=>"CA", "AvgQueueTime"=>"0", "Called"=>"+17209031774", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"80204", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", "CallSid"=>call_sid, "QueuePosition"=>"1", "CalledState"=>"CO", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", "CallStatus"=>"in-progress", "ToCity"=>"DENVER", "ToState"=>"CO", "To"=>"+17209031774", "ToCountry"=>"US", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"DENVER", "QueueTime"=>"0"}
  end

  def hold_initiate_params
    {"AccountSid"=>"ACdfefab935e1aee7582b5ff0af03c8df8", "ToZip"=>"80204", "FromState"=>"CA", "Called"=>"+17209031774", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"80204", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", "CallSid"=>"CONFCALL", "CalledState"=>"CO", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", "CallStatus"=>"in-progress", "ToCity"=>"DENVER", "ToState"=>"CO", "To"=>"+17209031774", "ToCountry"=>"US", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"DENVER"}
  end

  def unhold_params(call_sid = 'CONFCALL')
    {"AccountSid"=>"ACdfefab935e1aee7582b5ff0af03c8df8", "QueueSid"=>"QU2657d95fb2f5b6d2b249df601d4cf660", "ToZip"=>"80204", "FromState"=>"", "Called"=>"+17209031774", "FromCountry"=>"LS", "CallerCountry"=>"LS", "CalledZip"=>"80204", "Direction"=>"inbound", "FromCity"=>"", "CalledCountry"=>"US", "CallerState"=>"", "CallSid"=>call_sid, "CalledState"=>"CO", "From"=>"+266696687", "CallerZip"=>"", "FromZip"=>"", "CallStatus"=>"in-progress", "ToCity"=>"DENVER", "QueueResult"=>"redirected", "ToState"=>"CO", "To"=>"+17209031774", "ToCountry"=>"US", "CallerCity"=>"", "ApiVersion"=>"2010-04-01", "Caller"=>"+266696687", "CalledCity"=>"DENVER", "QueueTime"=>"10"}
  end

  def transfer_fallback_unhold_params(call_sid = 'CONFCALL')
    {"AccountSid"=>"ACdfefab935e1aee7582b5ff0af03c8df8", "QueueSid"=>"QUfc117592a7a8856fb6b23f42279fe6c9", "ToZip"=>"80204", "FromState"=>"CA", "Called"=>"+17209031774", "FromCountry"=>"US", "CallerCountry"=>"US", "CalledZip"=>"80204", "Direction"=>"inbound", "FromCity"=>"BAKERSFIELD", "CalledCountry"=>"US", "CallerState"=>"CA", "CallSid"=>call_sid, "CalledState"=>"CO", "From"=>"+16617480240", "CallerZip"=>"93307", "FromZip"=>"93307", "CallStatus"=>"in-progress", "ToCity"=>"DENVER", "QueueResult"=>"redirected", "ToState"=>"CO", "To"=>"+17209031774", "ToCountry"=>"US", "CallerCity"=>"BAKERSFIELD", "ApiVersion"=>"2010-04-01", "Caller"=>"+16617480240", "CalledCity"=>"DENVER", "QueueTime"=>"25"}
  end

  def create_freshfone_conf_call(call_sid = "CTRANSFER", call_status = 1, call_type = 1)
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
      :call_status => call_status, :call_type => call_type, :agent => @agent, :hold_queue => 'QU54ba1c05d41e0347a89be6e1535794c8',
      :params => { :CallSid => call_sid })
  end
 
  def create_freshfone_conf_call_meta(call, pinged_agents, meta_info = nil, hunt_type = :agent)
    @conf_call_meta = call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
      :hunt_type     => Freshfone::CallMeta::HUNT_TYPE[hunt_type],
      :meta_info => meta_info,:device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:browser],:pinged_agents => pinged_agents)
  end

  def create_conf_child_call(dial_call_sid = 'CTRANSFERCHILD',parent = @freshfone_call, agent = @agent)
    @freshfone_child_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
      :call_status => 0, :call_type => parent.call_type, :ancestry => parent.id, :agent => agent,
      :call_sid => parent.call_sid, :dial_call_sid => dial_call_sid)
  end
 
end