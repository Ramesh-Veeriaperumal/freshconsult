class Tickets::BulkTicketActions < BaseWorker

  sidekiq_options :queue => :bulk_ticket_actions, :retry => 0, :backtrace => true, :failures => :exhausted
  include Helpdesk::ToggleEmailNotification
  include Helpdesk::BulkActionMethods

  def perform(params)
    Thread.current[:sbrr_log] = [self.jid]
    ids = params["ids"]
    SBRR.logger.debug "BulkTicketActions #{ids.inspect}"
    @account = Account.current
    ids_join = ids.length > 0 ? ids.join(',') : '1' #'1' is dummy to prevent error
    items    = @account.tickets.order("field(display_id, #{ids_join})").find_all_by_param(ids)
    group_id = params["helpdesk_ticket"]["group_id"] if params["helpdesk_ticket"].present?
    items    = sort_items(items, group_id)
    disable_notification(@account) if params["disable_notification"].present? && 
                                      params["disable_notification"].to_bool
    group_ids = Set.new
    items.each do |ticket|
      ticket.schedule_observer = true if observer_inline?
      bulk_action_handler = Helpdesk::TicketBulkActions.new(params)
      bulk_action_handler.perform(ticket)
      run_observer_inline(ticket) if observer_inline?
      group_ids.merge (ticket.model_changes[:group_id] || [ticket.group_id])
    end
    group_ids.subtract([nil])
  rescue => e
      NewRelic::Agent.notice_error(e, {
        :custom_params => {
          :description => "Sidekiq Bulk actions error",
      }})
     raise e
  ensure
    sbrr_assigner(group_ids, {:jid => self.jid})
    enable_notification(@account)
    Thread.current[:sbrr_log] = nil
  end
end
