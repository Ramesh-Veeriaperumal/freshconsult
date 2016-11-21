class BroadcastMessages::NotifyBroadcastMessages < BaseWorker 

  sidekiq_options :queue => :notify_broadcast_message, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    tracker = Account.current.tickets.find_by_display_id(args[:tracker_display_id])
    related_tickets = tracker.associated_subsidiary_tickets("tracker") if tracker.present?
    return unless related_tickets.present?

    related_tickets.each do |rt|
      params = {
        ticket_display_id: rt.display_id,
        tracker_display_id: tracker.display_id,
        broadcast_id: args[:broadcast_id] }
      BroadcastMessages::NotifyAgent.perform_async(params)
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

end
