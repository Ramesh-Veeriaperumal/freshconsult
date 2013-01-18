class  Helpdesk::WatcherNotifier < ActionMailer::Base

  def notify_new_watcher(ticket, subscription, agent_name)
    subject       new_watcher_subject(ticket, agent_name)
    recipients    subscription.user.email
    from          ticket.friendly_reply_email
    body          :ticket => ticket, :subscription => subscription, :agent_name => agent_name
    sent_on       Time.now
    content_type  "text/html"
  end

  def notify_on_reply(ticket, subscription, note)
    subject       ticket_monitor_subject(ticket)
    recipients    subscription.user.email
    from          ticket.friendly_reply_email
    body          :ticket => ticket, :subscription => subscription, :note => note
    sent_on       Time.now
    content_type  "text/html"
  end

  def notify_on_status_change(ticket, subscription, status , agent_name)
    subject       ticket_monitor_subject(ticket)
    recipients    subscription.user.email
    from          ticket.friendly_reply_email
    body          :ticket => ticket, :subscription => subscription, :status => status, 
                  :agent_name => agent_name
    sent_on       Time.now
    content_type  "text/html"
  end

  def ticket_monitor_subject(ticket)
    "New Activity #{ticket.encode_display_id} #{ticket.subject} "
  end

  def new_watcher_subject(ticket, agent_name)
    " Added as Watcher #{ticket.encode_display_id} #{ticket.subject} "
  end
end