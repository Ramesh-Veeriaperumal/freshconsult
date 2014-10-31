class  Helpdesk::WatcherNotifier < ActionMailer::Base

  layout "email_font"

  def notify_new_watcher(ticket, subscription, agent_name)
    subject       new_watcher_subject(ticket, agent_name)
    recipients    subscription.user.email
    from          ticket.friendly_reply_email
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("notify_new_watcher.text.plain.erb", :ticket => ticket, :subscription => subscription, :agent_name => agent_name)
      end

      alt.part "text/html" do |html|
        html.body   render_message("notify_new_watcher.text.html.erb", :ticket => ticket, :subscription => subscription, 
                        :account => ticket.account, :agent_name => agent_name)
      end
    end
  end

  def notify_on_reply(ticket, subscription, note)
    subject       ticket_monitor_subject(ticket)
    recipients    subscription.user.email
    from          ticket.friendly_reply_email
    headers       "Reply-to" => "","Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("notify_on_reply.text.plain.erb", :ticket => ticket, :subscription => subscription, :note => note)
      end

      alt.part "text/html" do |html|
        html.body   render_message("notify_on_reply.text.html.erb", :ticket => ticket, :subscription => subscription, 
                                        :account => ticket.account, :note => note)
      end
    end
  end

  def notify_on_status_change(ticket, subscription, status , agent_name)
    subject       ticket_monitor_subject(ticket)
    recipients    subscription.user.email
    from          ticket.friendly_reply_email
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("notify_on_status_change.text.plain.erb",  :ticket => ticket, :subscription => subscription, 
                                    :status => status, :agent_name => agent_name)
      end

      alt.part "text/html" do |html|
        html.body   render_message("notify_on_status_change.text.html.erb", :ticket => ticket, :subscription => subscription, 
                                    :account => ticket.account, :status => status, :agent_name => agent_name)
      end
    end
  end

  def ticket_monitor_subject(ticket)
    "New Activity #{ticket.encode_display_id} #{ticket.subject} "
  end

  def new_watcher_subject(ticket, agent_name)
    " Added as Watcher #{ticket.encode_display_id} #{ticket.subject} "
  end
end