class Freshfone::Cron::CallRecordingAttachmentDelete
  def self.delete_twilio_recordings(freshfone_account)
    account = freshfone_account.account
    subaccount = account.freshfone_subaccount
    date = (Time.now.utc.ago 7.days)
    account.freshfone_calls.find_each(:batch_size => 1000,
    :conditions => ["recording_url IS NOT NULL AND updated_at BETWEEN ? AND ?", date.beginning_of_day, date.end_of_day]) do |call|
      next if call.recording_audio.blank?
      begin
        recording_sid = File.basename(call.recording_url)
        subaccount.recordings.get(recording_sid).delete
      rescue Exception => e
        NewRelic::Agent.notice_error(e, {:description => "Freshfone CallRecordingAttachmentDelete job 
          failed  account => #{call.account.id} :: call_id => #{call.id} :: call_sid => #{call.call_sid} :: recording_sid => #{recording_sid}"})
      end
    end 
  end
end