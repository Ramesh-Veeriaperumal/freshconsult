class Notes::NoteBodyJobs < BaseWorker 

  sidekiq_options :queue => :helpdesk_note_body_queue, :retry => 4, :backtrace => true, :failures => :exhausted

  def perform(args)
    begin
      args.symbolize_keys!
      args[:account_id] = Account.current.id
      bucket = S3_CONFIG[:note_body]
      unless args[:delete]
        note_body = Helpdesk::NoteOldBody.find_by_note_id_and_account_id(args[:key_id],args[:account_id])
        args[:data] = note_body.attributes
      end
      Helpdesk::S3::Note::Body.push_to_s3(args,bucket)
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:description => "error occured while pushing note body to s3"})
    end
  end
end


