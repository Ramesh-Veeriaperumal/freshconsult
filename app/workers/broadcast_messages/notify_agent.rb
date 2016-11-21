class BroadcastMessages::NotifyAgent < BaseWorker 

  sidekiq_options :queue => :broadcast_note, :retry => 3, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @tracker_ticket = Account.current.tickets.find_by_display_id(args[:tracker_display_id])
    @ticket = Account.current.tickets.find_by_display_id(args[:ticket_display_id])
    @broadcast_message = Account.current.broadcast_messages.find_by_id(args[:broadcast_id])
    return unless @tracker_ticket && @ticket && @broadcast_message
    send_notification
  rescue Exception => e
    NewRelic::Agent.notice_error(e, {
                                   :custom_params => {
                                     :description => "Broadcast Agent Error",
                                     :broadcast_message_id => args[:broadcast_message_id],
                                     :ticket_display_id    => args[:ticket_display_id]
      }})
      Rails.logger.error("Broadcast Agent Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
      # Re-raising the error to have retry
      raise e  
  end

  private

    def send_notification
      tkt_details = "[##{@ticket.display_id}] #{@ticket.subject}"
      url = Rails.application.routes.url_helpers.helpdesk_ticket_url(@ticket,
       :host => @ticket.portal_host,
       :protocol=> @ticket.url_protocol)
      DataExportMailer.deliver_broadcast_message({
        :to_email => recipients, 
        :subject => I18n.t("ticket.link_tracker.notifier_subject", :ticket_details => tkt_details),
        :from_email => @tracker_ticket.reply_email,
        :url => url,
        :ticket_subject => @ticket.subject,
        :content => @broadcast_message.body_html,
        :ticket_id => @ticket.display_id,
        :account_id => @ticket.account_id 
      })
    end

    def recipients
      watchers = @ticket.subscriptions.collect {|sub| sub.user if sub.user_id != User.current.try(:id) }
      watchers << @ticket.responder if @ticket.responder_id != User.current.try(:id)
      watchers.compact.collect {|w| w.email}.uniq.join(',')
    end

end