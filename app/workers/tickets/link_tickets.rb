class Tickets::LinkTickets < BaseWorker

  sidekiq_options :queue => :link_tickets, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @tracker_ticket = Account.current.tickets.find_by_display_id(args[:tracker_id])
    @related_tickets = Account.current.tickets.not_associated.permissible(User.current).readonly(false).where('display_id IN (?)', args[:related_ticket_ids])
    @tracker_ticket.misc_changes = {:tracker_link => @related_tickets.pluck(:display_id)}
    if Account.current.features?(:activity_revamp)
      @tracker_ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY)
    end
    return unless @tracker_ticket && @tracker_ticket.tracker_ticket? && @related_tickets.present? && !associations_count_exceeded?
    linked = []
    @related_tickets.each do |t|
      if t.can_be_linked?
        t.associates = [@tracker_ticket.display_id]
        t.update_attributes(
          :association_type => TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related],
          :associates_rdb => @tracker_ticket.display_id)
        linked << t.display_id
      end
    end
    @tracker_ticket.add_associates(linked)
    add_broadcast_notes(linked)
  end

  private

    def add_broadcast_notes linked_ticket_ids
      ::Tickets::AddBroadcastNote.perform_async(
        { :ticket_id => @tracker_ticket.id,
          :related_ticket_ids => linked_ticket_ids
        })
    end

    def associations_count_exceeded?
      ( @tracker_ticket.associates.nil? ? 0 : @tracker_ticket.associates.count ) + @related_tickets.count > TicketConstants::MAX_RELATED_TICKETS
    end
end
