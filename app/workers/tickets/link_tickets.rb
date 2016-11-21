class Tickets::LinkTickets < BaseWorker

  sidekiq_options :queue => :link_tickets, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @tracker_ticket = Account.current.tickets.find_by_display_id(args[:tracker_id])
    @related_tickets = Account.current.tickets.includes(:schema_less_ticket).not_associated.permissible(User.current).readonly(false).where('display_id IN (?)', args[:related_ticket_ids])
    @tracker_ticket.misc_changes = {:tracker_link => @related_tickets.pluck(:display_id)}
    if Account.current.features?(:activity_revamp)
      @tracker_ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY)
    end
    return unless @tracker_ticket && @tracker_ticket.tracker_ticket? && @related_tickets.present? && !associations_count_exceeded?
    linked = []
    @related_tickets.each do |t|
      if t.can_be_associated?
        t.associates = [@tracker_ticket.display_id]
        t.update_attributes(
          :association_type => TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related],
          :associates_rdb => @tracker_ticket.display_id)
        linked << t.display_id
      end
    end
    @tracker_ticket.add_associates(linked)
  rescue Exception => e
    NewRelic::Agent.notice_error(e, {:custom_params => {
                                            :description => "Link Tickets error",
                                            :args => args }})
    Rails.logger.error("Link Tickets Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
  end

  private

    def associations_count_exceeded?
      ( @tracker_ticket.associates.nil? ? 0 : @tracker_ticket.associates.count ) + @related_tickets.count > TicketConstants::MAX_RELATED_TICKETS
    end
end
