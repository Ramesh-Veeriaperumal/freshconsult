module Freshfone::Call::Branches::Missed

  def handle_missed_calls
    if missed_call?
      current_call.update_call(params)
      call_initiator.missed_call = true
      add_cost_job 
      params[:cost_added] = true
      render :xml =>  call_initiator.non_availability
    end
  end

  private
    def missed_call?
      #Redirect to voicemail on missed incoming calls and non-outgoing calls
      Freshfone::CallInitiator::VOICEMAIL_TRIGGERS.include?(params[:DialCallStatus]) and 
          !current_call.outgoing? and !call_transferred?
    end

end