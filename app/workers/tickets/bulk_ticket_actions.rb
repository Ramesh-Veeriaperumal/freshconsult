class Tickets::BulkTicketActions < BaseWorker

  sidekiq_options :queue => :bulk_ticket_actions, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(params)
    items = Helpdesk::Ticket.find_all_by_param(params["ids"])
    items.each do |ticket|
      bulk_action_handler = Helpdesk::TicketBulkActions.new(params)
      bulk_action_handler.perform(ticket)
    end
  rescue => e
      NewRelic::Agent.notice_error(e, {
        :custom_params => {
          :description => "Sidekiq Bulk actions error",
      }})
     raise e
  end
end