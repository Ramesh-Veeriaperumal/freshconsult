class Tickets::BulkChildTktCreation < BaseWorker

  sidekiq_options :queue => :bulk_child_tkt_creation, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    Ticket::ChildTicketWorker.new(args).child_tkt_create
  end
end