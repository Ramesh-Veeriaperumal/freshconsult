class Tickets::BulkTicketActions < BaseWorker

  sidekiq_options :queue => :bulk_ticket_actions, :retry => 0, :backtrace => true, :failures => :exhausted
  include Helpdesk::ToggleEmailNotification

  def perform(params)
    SBRR.logger.debug "BulkTicketActions #{params["ids"].inspect}"
    @account = Account.current
    items    = Helpdesk::Ticket.find_all_by_param(params["ids"])
    disable_notification(@account) if params["disable_notification"].present? && params["disable_notification"].to_bool
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
  ensure
    enable_notification(@account)
  end
end