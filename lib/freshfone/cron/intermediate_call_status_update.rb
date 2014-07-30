class Freshfone::Cron::IntermediateCallStatusUpdate

  def self.update_call_status (call, account)
    sid = call.is_root? ? call.call_sid : call.dial_call_sid
    return if (sid.blank? && !Freshfone::Call::INTERMEDIATE_CALL_STATUS.include?(call.call_status))
    
    call_status = twilio_call_status(account, sid) || final_call_status(call)
    if call_status.present? && call_status != call.call_status 
      call.call_status = call_status
      call.save
    end
  end

  def self.twilio_call_status(account, sid)
    begin
      status = account.freshfone_subaccount.calls.get(sid).status
      Freshfone::Call::CALL_STATUS_STR_HASH[status]
    rescue => e
      Rails.logger.debug "Twilio api request error in IntermediateCallStatusUpdate => #{e}"
    end
  end

  def self.final_call_status(call)
    if call.call_status == Freshfone::Call::CALL_STATUS_HASH[:default]
      Freshfone::Call::CALL_STATUS_HASH[:failed]
    end
  end

end