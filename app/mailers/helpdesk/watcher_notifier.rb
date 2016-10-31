class  Helpdesk::WatcherNotifier < ActionMailer::Base

  layout "email_font"
  include EmailHelper
  def notify_new_watcher(ticket, subscription, agent_name)
    headers = {
      :subject   => new_watcher_subject(ticket, agent_name),
      :to        => subscription.user.email,
      :from      => ticket.friendly_reply_email,
      :sent_on   => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers.merge!(make_header(ticket.display_id, nil, ticket.account_id, "Notify New Watcher"))
    @ticket = ticket
    @subscription = subscription
    @agent_name = agent_name
    @account = ticket.account
    mail(headers) do |part|
      part.text { render "notify_new_watcher.text.plain" }
      part.html { render "notify_new_watcher.text.html" }
    end.deliver
  end

  def notify_on_reply(ticket, subscription, note)
    headers = {
      :subject => ticket_monitor_subject(ticket),
      :to      => subscription.user.email,
      :from    => ticket.friendly_reply_email,
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers.merge!(make_header(ticket.display_id, nil, ticket.account_id, "Notify On Reply"))
    @ticket = ticket 
    @subscription = subscription 
    @note = note
    @account = ticket.account
    mail(headers) do |part|
      part.text { render "notify_on_reply.text.plain" }
      part.html { render "notify_on_reply.text.html" }
    end.deliver
  end

  def notify_on_status_change(ticket, subscription, status , agent_name)
    headers = {
      :subject => ticket_monitor_subject(ticket),
      :to      => subscription.user.email,
      :from    => ticket.friendly_reply_email,
      :sent_on => Time.now
    }
    headers.merge!(make_header(ticket.display_id, nil, ticket.account_id, "Notify On Status Change"))
    @ticket = ticket
    @subscription = subscription
    @status = status 
    @agent_name = agent_name
    @account = ticket.account
    mail(headers) do |part|
      part.text { render "notify_on_status_change.text.plain" }
      part.html { render "notify_on_status_change.text.html" }
    end.deliver
  end

  private
    def ticket_monitor_subject(ticket)
      "New Activity #{ticket.encode_display_id} #{ticket.subject} "
    end

    def new_watcher_subject(ticket, agent_name)
      " Added as Watcher #{ticket.encode_display_id} #{ticket.subject} "
    end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end