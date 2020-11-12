class Tickets::BulkTicketActions < BaseWorker

  sidekiq_options :queue => :bulk_ticket_actions, :retry => 0, :failures => :exhausted
  include Helpdesk::ToggleEmailNotification
  include Helpdesk::BulkActionMethods
  include Helpdesk::Ticketfields::TicketStatus
  include AdvancedTicketScopes

  attr_reader :status_list, :success_count

  MISSING_TICKET_ERROR_HASH = { field: 'ticket_id', message: 'ticket missing', code: 'invalid_ticket_id' }.freeze
  PERMISSION_DENIED_ERROR_HASH = { field: 'ticket_id', message: 'no permission to edit ticket', code: 'no_permission' }.freeze

  def perform(params)
    Thread.current[:sbrr_log] = [self.jid]
    ids = params["ids"]
    SBRR.logger.debug "BulkTicketActions #{ids.inspect}"
    @account = Account.current
    @status_list = []
    @success_count = 0
    ids_join = ids.length > 0 ? ids.join(',') : '1' #'1' is dummy to prevent error
    @items    = @account.tickets.order("field(display_id, #{ids_join})").find_all_by_param(ids)
    group_id = params["helpdesk_ticket"]["group_id"] if params["helpdesk_ticket"].present?
    sort_items(@items, group_id)
    disable_notification(@account) if params["disable_notification"].present? && 
                                      params["disable_notification"].to_bool
    params.symbolize_keys!
    @items.each do |ticket|
      bulk_update_tickets(ticket) do
        begin
          if check_background_job?(params) && delete_ticket_action?(params) && !check_ticket_delete_permission?(ticket)
            @status_list.push(id: ticket.display_id, success: false, error: PERMISSION_DENIED_ERROR_HASH)
            next
          end

          bulk_action_handler = Helpdesk::TicketBulkActions.new(params)
          bulk_action_handler.perform(ticket)
          @status_list.push(id: ticket.display_id, success: true)
          @success_count += 1
        rescue => e
          @status_list.push(id: ticket.display_id, success: false, error: { message: e.message })
          raise e unless check_background_job?(params)
        end
      end
    end
    missing_ids = ids.map(&:to_i) - @items.map(&:display_id)
    missing_ids.each do |id|
      @status_list.push(id: id, success: false, error: MISSING_TICKET_ERROR_HASH)
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

    def check_background_job?(params)
      params.key?(:bulk_background) && params[:bulk_background]
    end

    def delete_ticket_action?(params)
      params.key?(:action) && params[:action] == :delete
    end

    def check_ticket_delete_permission?(ticket)
      User.current && User.current.privilege?(:delete_ticket) && User.current.has_ticket_permission?(ticket)
    end
end
