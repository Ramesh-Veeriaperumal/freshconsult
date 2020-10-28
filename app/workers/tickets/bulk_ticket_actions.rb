class Tickets::BulkTicketActions < BaseWorker

  sidekiq_options :queue => :bulk_ticket_actions, :retry => 0, :failures => :exhausted
  include Helpdesk::ToggleEmailNotification
  include Helpdesk::BulkActionMethods
  include Helpdesk::Ticketfields::TicketStatus

  def perform(params)
    Thread.current[:sbrr_log] = [self.jid]
    ids = params["ids"]
    SBRR.logger.debug "BulkTicketActions #{ids.inspect}"
    @account = Account.current
    ids_join = ids.length > 0 ? ids.join(',') : '1' #'1' is dummy to prevent error
    @items    = @account.tickets.order("field(display_id, #{ids_join})").find_all_by_param(ids)
    group_id = params["helpdesk_ticket"]["group_id"] if params["helpdesk_ticket"].present?
    sort_items(@items, group_id)
    disable_notification(@account) if params["disable_notification"].present? && 
                                      params["disable_notification"].to_bool
    @items.each do |ticket|
      bulk_update_tickets(ticket) do
        bulk_action_handler = Helpdesk::TicketBulkActions.new(params)
        bulk_action_handler.perform(ticket)
      end
    end
    if cleanup_vault_data?(params)
      ticket_ids = @items.map(&:id)
      Tickets::VaultDataCleanupWorker.perform_async(object_ids: ticket_ids, action: 'close')
    end
  rescue => e
      NewRelic::Agent.notice_error(e, {
        :custom_params => {
          :description => "Sidekiq Bulk actions error",
      }})
     raise e
  ensure
    bulk_sbrr_assigner
    enable_notification(@account)
    Thread.current[:sbrr_log] = nil
  end

  private

    def cleanup_vault_data?(params)
      @account.secure_fields_enabled? && params[:action] == 'update_multiple' && params[:helpdesk_ticket] && params[:helpdesk_ticket]['status'] == CLOSED
    end
end
