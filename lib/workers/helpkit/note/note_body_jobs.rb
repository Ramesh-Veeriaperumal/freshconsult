class Workers::Helpkit::Note::NoteBodyJobs
  extend Resque::AroundPerform
  @queue = "helpdesk_note_body_queue"
  WorkerNoteBodyDelay = 1
  WorkerNoteBodyRetry = 4


  class << self
    def perform(args)
      begin
        bucket = S3_CONFIG[:note_body]
        unless args[:delete]
          note_body = Helpdesk::NoteOldBody.find_by_note_id_and_account_id(args[:key_id],args[:account_id])
          args[:data] = note_body.attributes
        end
        Helpdesk::S3::Note::Body.push_to_s3(args,bucket)
      rescue Exception => e
        # need to put the back to the resque
        args[:retry] = args[:retry].to_i + 1
        if args[:retry] < WorkerNoteBodyRetry
          args.delete(:data)
          Resque.enqueue_at(WorkerNoteBodyDelay.minutes.from_now, self, args)
        else
          raise e
        end
      end
    end
  end
end
