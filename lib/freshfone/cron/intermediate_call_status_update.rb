class Freshfone::Cron::IntermediateCallStatusUpdate

  def self.update_call_status (call, account)
    Account.reset_current_account
    @call = call
    @account = account
    sid = @call.dial_call_sid
    @account.make_current
    return if (sid.blank? && !Freshfone::Call::INTERMEDIATE_CALL_STATUS.include?(@call.call_status))
    get_twilio_call(sid)
    update_call_params
    recording_upload_job if can_initiate_uploding_job?
    calculate_call_cost
  ensure
    Account.reset_current_account
  end

  def self.get_twilio_call(sid)
    begin
      @twilio_call = @account.freshfone_subaccount.calls.get(sid)
    rescue => e
      Rails.logger.error "Twilio api request error in IntermediateCallStatusUpdate for account #{account.id} => #{e}"
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
    call_status = twilio_call_status || final_call_status
    @call.call_status = call_status if call_status.present?
    if @twilio_call.present?
      @call.call_duration = @twilio_call.duration 
      get_recording_url
    end
    @call.save
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
    Rails.logger.info "FreshfoneJob for sid : #{@call.call_sid} :: dsid : #{@call.dial_call_sid}"
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
    @call.direct_dial_number.present? || (@twilio_call.present? && @twilio_call.forwarded_from.present?)
  end

  def self.get_recording_url
    return if @call.recording_url.present? || @twilio_call.duration.to_i <= 5 || @twilio_call.parent_call_sid.blank?
    recording = get_parent_call.recordings.list.first
    @call.recording_url = "http://api.twilio.com#{recording.uri.gsub(".json","")}" if recording.present?
  end

  def self.get_parent_call
    @twilio_parent_call = @account.freshfone_subaccount.calls.get(@twilio_call.parent_call_sid)
  end
end