module AgentConferenceSpecHelper
  def enable_agent_conference
    @account.launch(:agent_conference) unless @account.launched?(:agent_conference)
  end

  def add_agent_params(agent_id)
    { call: @freshfone_call.id, target: agent_id }
  end

  def cancel_params
    { CallSid: @freshfone_call.call_sid }
  end

  def add_agent_success_params
   {"ApiVersion"=>"2010-04-01", "Called"=>"client:#{@dummy_users[1].id}", "CallStatus"=>"in-progress", 
    "From"=>"+266696687", "CallerCountry"=>"LS", "Direction"=>"outbound-api", 
    "AccountSid"=>"ACec751ff2beab6c5c8d97c673b89d152a", "CallerCity"=>"", "CallerState"=>"", 
    "Caller"=>"+266696687", "FromCountry"=>"LS", "FromCity"=>"", "CallSid"=>@agent_conference_call.sid, 
    "To"=>"client:#{@dummy_users[1].id}", "FromZip"=>"", "CallerZip"=>"", "FromState"=>"",
    "call"=> @freshfone_call.id, "add_agent_call_id"=> @agent_conference_call.id}
  end

  def add_agent_status_params
    {"ApiVersion"=>"2010-04-01", "Called"=>"client:#{@dummy_users[1].id}", "CallStatus"=>"completed",
      "Duration"=>"1", "From"=>"+266696687", "CallerCountry"=>"LS","Direction"=>"outbound-api",
      "CallDuration"=>10, "Timestamp"=>"Tue, 26 Apr 2016 05:02:09 +0000",
      "AccountSid"=>"ACec751ff2beab6c5c8d97c673b89d152a", "CallbackSource"=>"call-progress-events",
      "CallerCity"=>"", "CallerState"=>"", "Caller"=>"+266696687", "FromCountry"=>"LS",
      "FromCity"=>"", "SequenceNumber"=>"0", "CallSid"=>@agent_conference_call.sid,
      "To"=>"client:#{@dummy_users[1].id}", "FromZip"=>"", "CallerZip"=>"", "FromState"=>"",
      "call"=>@freshfone_call.id,"add_agent_call_id"=>@agent_conference_call.id}
  end
end
