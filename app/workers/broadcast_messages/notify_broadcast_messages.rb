class BroadcastMessages::NotifyBroadcastMessages < BaseWorker 

  sidekiq_options :queue => :notify_broadcast_message, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    tracker = Account.current.tickets.find_by_display_id(args[:tracker_display_id])
    related_tickets = tracker.associated_subsidiary_tickets("tracker") if tracker.present?
    return unless related_tickets.present?

    related_tickets.each do |rt|
      to_emails = recipients(rt)
      if to_emails.present?
        params = {
          ticket_display_id: rt.display_id,
          tracker_display_id: tracker.display_id,
          broadcast_id: args[:broadcast_id],
          recipients: to_emails }
        BroadcastMessages::NotifyAgent.perform_async(params)
      end
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e, {
      :custom_params => {
        :description => "error occured while Notifying broadcast messages to agents",
        :account_id => Account.current.id,
        :broadcast_id => args[:broadcast_id]
      }
    })
  end


  def recipients(ticket)
    watchers = ticket.subscriptions.collect {|sub| sub.user if sub.user_id != User.current.try(:id) }
    watchers << ticket.responder if ticket.responder_id != User.current.try(:id)
    watchers.compact.collect {|w| w.email}.uniq.join(',')
  end

end
