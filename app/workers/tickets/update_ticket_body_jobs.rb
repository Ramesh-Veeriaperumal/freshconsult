class Tickets::UpdateTicketBodyJobs < BaseWorker 

  sidekiq_options :queue => :helpdesk_update_ticket_body_queue, :retry => 4, :failures => :exhausted
 
  def perform(args)
    begin
      args.symbolize_keys!
      args[:account_id] = Account.current.id
      bucket = S3_CONFIG[:ticket_body]
      ticket_body = Helpdesk::TicketOldBody.find_by_ticket_id_and_account_id(args[:key_id],args[:account_id])
      return unless ticket_body
      args[:data] = ticket_body.attributes
      Helpdesk::S3::Ticket::Body.push_to_s3(args,bucket)
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:description => "error occured while updating ticket body to s3"})
    end
  end
end
