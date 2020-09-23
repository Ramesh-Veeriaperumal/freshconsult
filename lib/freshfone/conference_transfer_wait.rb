class Freshfone::ConferenceTransferWait
  extend Resque::AroundPerform

  @queue = "freshfone_queue_wait"
  
  def self.perform(args)
    begin
      account = Account.current
      call_id = args[:call_id]
      call = account.freshfone_calls.find(call_id) if call_id.present?
      return if call.blank? || !call.onhold?
      call.disconnect_customer
      calculate_total_duration(account, call)
    rescue Exception => e
      Rails.logger.debug "Error in processing On Hold Freshfone Conference Transfer Calls For Account: #{args[:account_id]} For Call: #{args[:call_id]}:: \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e)
    end
  end

  def self.get_twilio_call(account, call)
    account.freshfone_account.twilio_subaccount.calls.get(call.call_sid)
  end

  def self.calculate_total_duration(account, call)
    twilio_call = get_twilio_call(account, call)
    call.total_duration = twilio_call.duration if twilio_call.present? && twilio_call.duration.present? && !call.incoming_root_call?
    call.total_duration = (Time.now.utc - call.created_at) if call.total_duration.blank?
    call.save!
  end

end
