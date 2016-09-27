class Tickets::AddBroadcastNote < BaseWorker

  sidekiq_options :queue => :broadcast_note, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    @args = args.symbolize_keys!
    @tracker_ticket = Account.current.tickets.find_by_id(args[:ticket_id])
    return if @tracker_ticket.nil?
    @broadcast_note = @tracker_ticket.notes.find_by_id(args[:note_id]) || @tracker_ticket.notes.broadcast_notes.last
    related_tickets_broadcast if @broadcast_note.present?
  end

  private

  def related_tickets_broadcast
    @broadcast_note.user.make_current
    related_tickets.each do |tkt|
      note = tkt.notes.new(note_params)
      note.save_note
      send_notifications(tkt)
    end
  end

  def related_tickets
    @related_tickets ||= begin
      if @args[:related_ticket_ids].present?
        Account.current.tickets.permissible(User.current).where('display_id IN (?)', @args[:related_ticket_ids])
      else
        @tracker_ticket.related_tickets([:responder])
      end
    end
  end

  def note_params
    {
      :note_body_attributes => { :body_html => @broadcast_note.body_html },
      :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['tracker'],
      :category => Helpdesk::Note::CATEGORIES[:broadcast],
      :user_id => User.current.id,
      :created_at => @broadcast_note.created_at,
      :updated_at => @broadcast_note.updated_at
    }
  end

  def send_notifications(ticket)
    recipients(ticket).each do |recipient|
      tkt_details = "[##{ticket.display_id}] #{ticket.subject}"
      url = Rails.application.routes.url_helpers.helpdesk_ticket_url(ticket,
       :host => ticket.account.full_domain,
       :protocol=> ticket.url_protocol)
      DataExportMailer.deliver_broadcast_message({
        :to_email => recipient.email, 
        :subject => I18n.t("ticket.link_tracker.notifier_subject", :ticket_details => tkt_details),
        :from_email => @tracker_ticket.reply_email,
        :url => url,
        :ticket_subject => ticket.subject,
        :content => @broadcast_note.body_html
      })
    end
  end

  def recipients(ticket)
    watchers = ticket.subscriptions.collect {|sub| sub.user if sub.user_id != User.current.id }
    watchers << ticket.responder
    watchers.compact
  end

end
