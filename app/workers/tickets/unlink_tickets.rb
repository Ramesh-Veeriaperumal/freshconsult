class Tickets::UnlinkTickets < BaseWorker

  sidekiq_options :queue => :unlink_tickets, :retry => 0, :failures => :exhausted

  def perform(args)
    current_account  = Account.current
    args.symbolize_keys!
    @related_tickets = current_account.tickets.includes(:schema_less_ticket).readonly(false).where('display_id IN (?)', args[:related_ticket_ids])
    return unless @related_tickets.present?
    @related_tickets.each do |ticket|
      if tracker_ticket_permission?(ticket.associates_rdb)
        ticket.tracker_ticket_id = ticket.associates_rdb
        ticket.update_attributes(:association_type => nil)
      end
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e, {:custom_params => {
                                            :description => "Unlink Tickets error :: #{current_account.id}",
                                            :args => args }})
    Rails.logger.error("Unlink Tickets Error: #{current_account.id}: #{e.message} #{e.backtrace.join("\n")}")
  end

  private

  def tracker_ticket_permission? tracker_id
    @tracker_ids ||= []
    if @tracker_ids.include?(tracker_id) || (tracker_ticket = 
      Account.current.tickets.permissible(User.current).find_by_display_id(tracker_id))
      @tracker_ids << tracker_ticket.display_id if tracker_ticket
      return true
    end
    false
  end
end