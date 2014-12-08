class Freshfone::Cron::IntermediateCallStatusUpdate

  def self.update_call_status (call, account)
    @call = call
    sid = @call.dial_call_sid
    return if (sid.blank? && !Freshfone::Call::INTERMEDIATE_CALL_STATUS.include?(@call.call_status))
    
    call_status = twilio_call_status(account, sid) || final_call_status
    if call_status.present? && call_status != @call.call_status 
      @call.call_status = call_status
      @call.save
      recording_upload_job if can_initiate_uploding_job?
    end
  end

  def self.twilio_call_status(account, sid)
    begin
      status = account.freshfone_subaccount.calls.get(sid).status
      Freshfone::Call::CALL_STATUS_STR_HASH[status]
    rescue => e
      Rails.logger.debug "Twilio api request error in IntermediateCallStatusUpdate for account #{account.id} => #{e}"
      return nil
    end
  end

  def self.final_call_status
    if @call.call_status == Freshfone::Call::CALL_STATUS_HASH[:default]
      Freshfone::Call::CALL_STATUS_HASH[:failed]
    end
  end

  def self.is_voicemail?
    @call.call_status == Freshfone::Call::CALL_STATUS_HASH[:'no-answer'] ||
    (@call.call_status == Freshfone::Call::CALL_STATUS_HASH[:busy] && 
      @call.call_type.to_i == Freshfone::Call::CALL_TYPE_HASH[:incoming] )
  end

  def self.recording_upload_job
    record_params = {
        :account_id => @call.account_id, 
        :call_sid => @call.call_sid,
        :call_id => @call.id,
        :call_duration => @call.call_duration
      }
    record_params.merge!({:voicemail => true}) if is_voicemail?
    Resque::enqueue(Freshfone::Jobs::CallRecordingAttachment, record_params)
  end

  def self.can_initiate_uploding_job?
    @call.recording_url.present? && @call.recording_audio.blank?
  end

end