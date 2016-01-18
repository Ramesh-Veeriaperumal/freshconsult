class Workers::Helpkit::Ticket::TicketBodyJobs
  extend Resque::AroundPerform
  # in minutes
  WorkerTicketBodyDelay = 1
  WorkerTicketBodyRetry = 4

  @queue = "helpdesk_ticket_body_queue"
  
  class << self
    def perform(args)
      begin
        bucket = S3_CONFIG[:ticket_body]
        unless args[:delete]
          ticket_body = Helpdesk::TicketOldBody.find_by_ticket_id_and_account_id(args[:key_id],args[:account_id])
          tkt_body_size = ticket_body.description.bytesize
          # $statsd.increment "ticket_body.#{args[:account_id]}.#{args[:requester_id]}" , tkt_body_size
          if args[:retry].to_i < (WorkerTicketBodyRetry-1)
            args[:data] = ticket_body.attributes
          else
            return if ticket_body.blank?
            args[:data] = ticket_body.attributes
          end
        end
        Helpdesk::S3::Ticket::Body.push_to_s3(args,bucket)
      rescue Exception => e
        # need to put the back to the resque
        args[:retry] = args[:retry].to_i + 1
        if args[:retry] < WorkerTicketBodyRetry
          args.delete(:data)
          Resque.enqueue_at(WorkerTicketBodyDelay.minutes.from_now, self, args) 
        else
          raise e
        end
      end
    end
  end
end
