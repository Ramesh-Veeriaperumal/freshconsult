class  Helpdesk::TicketNotifier < ActionMailer::Base
  
  def self.notify_by_email(notification_type, ticket, comment = nil)
    e_notification = ticket.account.email_notifications.find_by_notification_type(notification_type)
    if e_notification.agent_notification?
      a_template = Liquid::Template.parse(e_notification.formatted_agent_template)
      a_s_template = Liquid::Template.parse(e_notification.agent_subject_template)
      i_receips = internal_receips(e_notification, ticket)
      deliver_email_notification({ :ticket => ticket,
             :notification_type => notification_type,
             :receips => i_receips,
             :email_body => a_template.render('ticket' => ticket, 
                'helpdesk_name' => ticket.account.portal_name, 'comment' => comment),
             :subject => a_s_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
          }) unless i_receips.nil?
    end
    
    if e_notification.requester_notification? and !ticket.out_of_office?
      r_template = Liquid::Template.parse(e_notification.formatted_requester_template)
      r_s_template = Liquid::Template.parse(e_notification.requester_subject_template)
      params = { :ticket => ticket,
             :notification_type => notification_type,
             :receips => ticket.requester.email,
             :email_body => r_template.render('ticket' => ticket, 
                'helpdesk_name' => ticket.account.portal_name, 'comment' => comment),
             :subject => r_s_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)}
      if(notification_type == EmailNotification::NEW_TICKET and ticket.source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone])
        params[:attachments] = ticket.attachments
      end
      deliver_email_notification(params) if ticket.requester_has_email?
    end
  end
  
  
  
  def self.internal_receips(e_notification, ticket)
    if(e_notification.notification_type == EmailNotification::TICKET_ASSIGNED_TO_GROUP)
      unless ticket.group.nil?
        to_ret = ticket.group.agent_emails
        return to_ret unless to_ret.empty?
      end
    elsif(e_notification.notification_type == EmailNotification::NEW_TICKET)
        to_ret = e_notification.agents.collect { |a| a.email }
        return to_ret unless to_ret.empty?  
    else
      ticket.responder.email unless ticket.responder.nil?
    end
  end
  
  def email_notification(params)
    subject       params[:subject]
    recipients    params[:receips]
    body          :ticket => params[:ticket], :body => params[:email_body],
                  :survey_handle => SurveyHandle.create_handle_for_notification(params[:ticket], 
                    params[:notification_type])
    from          params[:ticket].friendly_reply_email
    headers       "Reply-to" => "#{params[:ticket].friendly_reply_email}"
    sent_on       Time.now
    params[:attachments].each do |a|
      attachment  :content_type => a.content_content_type,
                  :body => File.read(a.content.to_file.path),
                  :filename => a.content_file_name
    end
    content_type  "text/html"
  end
 
  def reply(ticket, note , reply_email, options={})
    subject       formatted_subject(ticket)
    recipients    ticket.requester.email
    cc            ticket.cc_email_hash[:cc_emails] if !options[:include_cc].blank? and !ticket.cc_email.nil?
    bcc           options[:bcc_emails]
    from          reply_email
    body          :ticket => ticket, :body => note.body_html,
                  :survey_handle => SurveyHandle.create_handle(ticket, note)
    headers       "Reply-to" => "#{reply_email}"
    sent_on       Time.now
    content_type  "multipart/alternative"

    note.attachments.each do |a|
      attachment  :content_type => a.content_content_type, 
                  :body => File.read(a.content.to_file.path), 
                  :filename => a.content_file_name
    end
    
    content_type  "text/html"
  end

  def forward(ticket, note , reply_email, options={})
    subject       fwd_formatted_subject(ticket)
    recipients    options[:to_emails]
    cc            options[:fwd_cc_emails] unless options[:include_cc].blank?
    bcc           options[:bcc_emails]
    from          reply_email
    body          :ticket => ticket, :body => note.body_html
    headers       "Reply-to" => "#{reply_email}"
    sent_on       Time.now
    content_type  "multipart/alternative"

    note.attachments.each do |a|
      attachment  :content_type => a.content_content_type, 
                  :body => File.read(a.content.to_file.path), 
                  :filename => a.content_file_name
    end
    
    content_type  "text/html"
  end
  
  def notify_comment(ticket, note , reply_email, options={})
    subject       formatted_subject(ticket)
    recipients    options[:notify_emails]     
    body          :ticket => ticket, :note => note , :ticket_url => helpdesk_ticket_url(ticket,:host => ticket.account.host)          
    from          reply_email
    headers       "Reply-to" => "#{reply_email}"
    sent_on       Time.now
    content_type  "text/html"
  end
  
  def email_to_requester(ticket, content)
    subject       formatted_subject(ticket)
    recipients    ticket.requester.email
    from          ticket.friendly_reply_email
    body          content
    headers       "Reply-to" => "#{ticket.friendly_reply_email}"
    sent_on       Time.now
    content_type  "text/html"
  end
  
  def internal_email(ticket, receips, content)
    subject       formatted_subject(ticket)
    recipients    receips
    from          ticket.friendly_reply_email
    body          content
    headers       "Reply-to" => "#{ticket.friendly_reply_email}"
    sent_on       Time.now
    content_type  "text/html"
  end
  
  def formatted_subject(ticket)
    "Re: #{ticket.encode_display_id} #{ticket.subject}"
  end

  def fwd_formatted_subject(ticket)
    "Fwd: #{ticket.encode_display_id} #{ticket.subject}"
  end
end
