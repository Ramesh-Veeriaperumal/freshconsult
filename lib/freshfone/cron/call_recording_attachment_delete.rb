class Freshfone::Cron::CallRecordingAttachmentDelete
  def self.delete_twilio_recordings(account)
    Rails.logger.debug "Initiating call recording delete for account #{account.id} "
    subaccount = account.freshfone_subaccount
    date = (Time.now.utc.ago 7.days)
    account.freshfone_calls.find_each(:batch_size => 500,
    :conditions => ["recording_url IS NOT NULL AND updated_at BETWEEN ? AND ?", date.beginning_of_day, date.end_of_day]) do |call|
      next if call.recording_audio.blank?
      begin
        recording_sid = File.basename(call.recording_url)
        Rails.logger.debug "Deleting attachment #{recording_sid} for #{account.id}"
        subaccount.recordings.get(recording_sid).delete
      rescue Exception => e
        description = "Freshfone CallRecordingAttachmentDelete job failed  account => #{call.account.id} :: call_id => #{call.id} :: call_sid => #{call.call_sid} :: recording_sid => #{recording_sid}"
        Rails.logger.debug description
        NewRelic::Agent.notice_error(e, {:description => description})
      end
    end 
  end
end