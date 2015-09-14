class Freshfone::Cron::IntermediateCallStatusUpdate

  def self.update_call_status (call, account)
    Account.reset_current_account
    Rails.logger.debug "Call status update for account #{account.id} :: Call id #{call.id}"
    @call = call
    @account = account
    sid = @call.dial_call_sid
    @account.make_current
    if (!Freshfone::Call::INTERMEDIATE_CALL_STATUS.include?(@call.call_status))
      Rails.logger.debug "IntermediateCallStatusUpdate : Not an intermediate call for account #{@account.id} :: Call id #{call.id}"
      return
    end
    sid.present?  ?  update_from_api(sid) : update_as_missed_call
    calculate_call_cost if @call.call_cost.blank?
  ensure
    Account.reset_current_account
  end

  
  def self.update_from_api(sid)
    get_twilio_call(sid)
    update_call_params
    recording_upload_job if can_initiate_uploding_job?
  end

  def self.get_twilio_call(sid)
    begin
      @twilio_call = @account.freshfone_subaccount.calls.get(sid)
    rescue => e
      Rails.logger.error "IntermediateCallStatusUpdate : Twilio api request error in IntermediateCallStatusUpdate for account #{@account.id} => #{e}"
      return nil
    end
  end

  def self.twilio_call_status
    return @twilio_call.present? ? Freshfone::Call::CALL_STATUS_STR_HASH[@twilio_call.status] : false
  end

  def self.final_call_status
    if @call.call_status == Freshfone::Call::CALL_STATUS_HASH[:default]
      Freshfone::Call::CALL_STATUS_HASH[:failed]
    end
  end

  def self.update_call_params
    begin
      call_status = twilio_call_status || final_call_status
      @call.call_status = call_status if call_status.present?
      if @twilio_call.present?
        @call.call_duration = @twilio_call.duration
        @call.total_duration = @twilio_call.duration if @account.features?(:freshfone_conference)
        get_recording_url
      end
      Rails.logger.debug "IntermediateCallStatusUpdate : Call param update for account #{@account.id} :: 
        Call id => #{@call.id} :: status => #{@call.call_status} :: duration => #{@call.call_duration} ::
         recording_url => #{@call.recording_url} :: total_duration => #{@call.total_duration}"
      @call.save
    rescue => e
      Rails.logger.error "IntermediateCallStatusUpdate : Twilio api request error in IntermediateCallStatusUpdate for account #{@account.id} :: #{@call.id} => #{e}"
      return nil
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

  def self.calculate_call_cost
    Resque::enqueue(Freshfone::Jobs::CallBilling, cost_params)
    Rails.logger.info "IntermediateCallStatusUpdate : Call cost calculation for account #{@account.id} :: 
      Call ID :: #{@call.id} FreshfoneJob for sid : #{@call.call_sid} :: dsid : #{@call.dial_call_sid}"
  end

  def self.cost_params
    { :account_id => @call.account_id,
      :call_sid => @call.call_sid,
      :dial_call_sid => @call.dial_call_sid,
      :call => @call.id,
      :call_forwarded => call_forwarded?,
      :number_id => @call.freshfone_number_id
    }
  end

  def self.call_forwarded?
    @call.direct_dial_number.present? || has_forwarded_from_param?
  end

  def self.get_recording_url
    return if @call.recording_url.present? || @twilio_call.duration.to_i <= 5 || @twilio_call.parent_call_sid.blank?
    recording = get_parent_call.recordings.list.first
    @call.recording_url = "http://api.twilio.com#{recording.uri.gsub(".json","")}" if recording.present?
  end

  def self.get_parent_call
    @twilio_parent_call = @account.freshfone_subaccount.calls.get(@twilio_call.parent_call_sid)
  end

  def self.has_forwarded_from_param?
    begin
      (@twilio_call.present? && @twilio_call.forwarded_from.present?)   
    rescue Exception => e
      Rails.logger.error "IntermediateCallStatusUpdate : Twilio api request error has_forwarded_from_param account #{@account.id} :: #{@call.id} => #{e}"
      return false
    end
  end

  def self.update_as_missed_call
    Rails.logger.debug "IntermediateCallStatusUpdate : Missed call update for account #{@account.id} :: Call id => #{@call.id} :: status => no-answer"
    @call.noanswer!
  end
end