class Workers::Helpkit::Ticket::UpdateTicketBodyJobs
  extend Resque::AroundPerform

  @queue = "helpdesk_update_ticket_body_queue"
  WorkerUpdateTicketBodyDelay = 1
  WorkerUpdateTicketBodyRetry = 4

  class << self
    def perform(args)
      begin
        bucket = S3_CONFIG[:ticket_body]
        ticket_body = Helpdesk::TicketOldBody.find_by_ticket_id_and_account_id(args[:key_id],args[:account_id])
        args[:data] = ticket_body.attributes
        Helpdesk::S3::Ticket::Body.push_to_s3(args,bucket)
      rescue Exception => e
        # need to put the back to the resque
        args[:retry] = args[:retry].to_i + 1
        if args[:retry] < WorkerUpdateTicketBodyRetry
          args.delete(:data)
          Resque.enqueue_at(WorkerUpdateTicketBodyDelay.minutes.from_now, self, args)
        else
          raise e
        end
      end
    end
  end
end
