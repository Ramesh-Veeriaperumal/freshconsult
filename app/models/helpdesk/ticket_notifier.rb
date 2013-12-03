# encoding: utf-8
class  Helpdesk::TicketNotifier < ActionMailer::Base

  include Helpdesk::NotifierFormattingMethods
  
  def self.notify_by_email(notification_type, ticket, comment = nil)
    e_notification = ticket.account.email_notifications.find_by_notification_type(notification_type)
    if e_notification.agent_notification?
      if (notification_type == EmailNotification::NEW_TICKET)
        e_notification.agents.group_by{|agent| agent[:language]}.each do |email_agents|
          agents = email_agents.last
          i_receips = agents.collect{ |a| a.email }
          deliver_agent_notification(agents.first, i_receips, e_notification, ticket, comment)          
        end  
      else  
        i_receips = internal_receips(e_notification, ticket)
        deliver_agent_notification(ticket.responder, i_receips, e_notification, ticket, comment)
      end 
    end
    
    if e_notification.requester_notification? and !ticket.out_of_office?
      requester_template = e_notification.get_requester_template(ticket.requester)
      requester_plain_template = e_notification.get_requester_plain_template(ticket.requester)
      r_template = Liquid::Template.parse(requester_template.last.gsub("{{ticket.status}}","{{ticket.requester_status_name}}")) 
      r_plain_template = Liquid::Template.parse(requester_plain_template.gsub("{{ticket.status}}","{{ticket.requester_status_name}}").gsub("{{ticket.description}}", "{{ticket.description_text}}"))
      r_s_template = Liquid::Template.parse(requester_template.first.gsub("{{ticket.status}}","{{ticket.requester_status_name}}")) 
      html_version = r_template.render('ticket' => ticket, 
                'helpdesk_name' => ticket.account.portal_name, 'comment' => comment).html_safe
      plain_version = r_plain_template.render('ticket' => ticket, 
                'helpdesk_name' => ticket.account.portal_name, 'comment' => comment).html_safe
      params = { :ticket => ticket,
             :notification_type => notification_type,
             :receips => ticket.requester.email,
             :email_body_plain => plain_version,
             :email_body_html => html_version,
             :subject => r_s_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name).html_safe}
      if(notification_type == EmailNotification::NEW_TICKET and ticket.source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone])
        params[:attachments] = ticket.attachments
        params[:dropboxes] = ticket.dropboxes
      end
      deliver_email_notification(params) if ticket.requester_has_email?
    end
  end

  def self.deliver_agent_notification(agent, receips, e_notification, ticket, comment)
      agent_template = e_notification.get_agent_template(agent)
      agent_plain_template = e_notification.get_agent_plain_template(agent)
      a_template = Liquid::Template.parse(agent_template.last) 
      a_plain_template = Liquid::Template.parse(agent_plain_template.gsub("{{ticket.description}}", "{{ticket.description_text}}"))
      a_s_template = Liquid::Template.parse(agent_template.first) 
      html_version = a_template.render('ticket' => ticket, 
                'helpdesk_name' => ticket.account.portal_name, 'comment' => comment).html_safe
      plain_version = a_plain_template.render('ticket' => ticket, 
                'helpdesk_name' => ticket.account.portal_name, 'comment' => comment).html_safe
      deliver_email_notification({ :ticket => ticket,
             :notification_type => e_notification.notification_type,
             :receips => receips,
             :email_body_plain => plain_version,
             :email_body_html => html_version,
             :subject => a_s_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name).html_safe
          }) unless receips.nil?
  end

  def self.internal_receips(e_notification, ticket)
    if(e_notification.notification_type == EmailNotification::TICKET_ASSIGNED_TO_GROUP)
      unless ticket.group.nil?
        to_ret = ticket.group.agent_emails
        return to_ret unless to_ret.empty?
      end
    else
      ticket.responder.email unless ticket.responder.nil?
    end
  end
   
  def email_notification(params)
    subject       params[:subject]
    recipients    params[:receips]
    from          params[:ticket].friendly_reply_email
    bcc           account_bcc_email(params[:ticket])
    headers       "Reply-to" => "#{params[:ticket].friendly_reply_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply", "References" => generate_email_references(params[:ticket])
    sent_on       Time.now
    content_type  "multipart/mixed"

    inline_attachments = []
    
    part :content_type => "multipart/alternative" do |alt|
       alt.part "text/plain" do |plain|
         plain.body  render_message("email_notification.text.plain.erb",:ticket => params[:ticket], :body => params[:email_body_plain], :dropboxes=>params[:dropboxes],
                     :survey_handle => SurveyHandle.create_handle_for_notification(params[:ticket], 
                     params[:notification_type]),
                     :surveymonkey_survey =>  Integrations::SurveyMonkey.survey_for_notification(params[:notification_type], params[:ticket]))
       end
      alt.part "text/html" do |html|
        html.body   render_message("email_notification.text.html.erb",:ticket => params[:ticket], 
                    :body => generate_body_html(params[:email_body_html], inline_attachments, params[:ticket].account), :dropboxes=>params[:dropboxes],
                    :survey_handle => SurveyHandle.create_handle_for_notification(params[:ticket], 
                    params[:notification_type]),
                    :surveymonkey_survey =>  Integrations::SurveyMonkey.survey_for_notification(params[:notification_type], params[:ticket]))
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?

    params[:attachments].each do |a|
      attachment  :content_type => a.content_content_type,
                  :body => File.read(a.content.to_file.path),
                  :filename => a.content_file_name
    end
  end

  def export(params, string_csv, recipient)
    subject       formatted_export_subject(params).to_s + " -- " + Account.current.full_domain.to_s
    recipients    recipient.email
    body          :user => recipient
    from          AppConfig['from_email']
    #bcc - Temporary fix for reports. Need to remove when ticket export is fully done.
    bcc           "reports@freshdesk.com"
    sent_on       Time.now
    content_type  "multipart/alternative"

    attachment    :content_type => 'text/csv; charset=utf-8; header=present', 
                  :body => string_csv, 
                  :filename => 'tickets.csv'

    content_type  "text/html"
  end

  def export_xls(params, xls_string, recipient)
    subject       formatted_export_subject(params).to_s + " -- " + Account.current.full_domain.to_s
    recipients    recipient.email
    body          :user => recipient
    from          AppConfig['from_email']
    #bcc - Temporary fix for reports. Need to remove when ticket export is fully done.
    bcc           "reports@freshdesk.com"
    sent_on       Time.now
    content_type  "multipart/alternative"

    attachment    :content_type => 'text/xls; charset=utf-8; header=present', 
                  :body => xls_string, 
                  :filename => 'tickets.xls'

    content_type  "text/html"
  end
 
  def reply(ticket, note , options={})

    options = {} unless options.is_a?(Hash) 
    
    subject       formatted_subject(ticket)
    recipients    note.to_emails
    cc            note.cc_emails unless options[:include_cc].blank?
    bcc           note.bcc_emails
    from          note.from_email
    headers       "Reply-to" => "#{note.from_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply", "References" => generate_email_references(ticket)
    sent_on       Time.now
    content_type  "multipart/mixed"

    inline_attachments = []
    
    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body   render_message("reply.text.plain.erb",:ticket => ticket, :body => note.full_text, :note => note, 
                    :dropboxes=>note.dropboxes, :survey_handle => SurveyHandle.create_handle(ticket, note, options[:send_survey]),
                    :include_quoted_text => options[:quoted_text],
                    :surveymonkey_survey =>  Integrations::SurveyMonkey.survey(options[:include_surveymonkey_link], ticket, note.user)
                    )
      end
      alt.part "text/html" do |html|
        html.body   render_message("reply.text.html.erb", :ticket => ticket, 
                    :body => generate_body_html(note.full_text_html, inline_attachments, note.account), :note => note, 
                    :dropboxes=>note.dropboxes, :survey_handle => SurveyHandle.create_handle(ticket, note, options[:send_survey]),
                    :include_quoted_text => options[:quoted_text],
                    :surveymonkey_survey =>  Integrations::SurveyMonkey.survey(options[:include_surveymonkey_link], ticket, note.user)
                    )
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?

    note.all_attachments.each do |a|
      attachment  :content_type => a.content_content_type, 
                  :body => File.read(a.content.to_file.path), 
                  :filename => a.content_file_name
    end
  end
  
  def forward(ticket, note, options={})
    subject       fwd_formatted_subject(ticket)
    recipients    note.to_emails
    cc            note.cc_emails
    bcc           note.bcc_emails
    from          note.from_email
    headers       "Reply-to" => "#{note.from_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply", "References" => generate_email_references(ticket)
    sent_on       Time.now
    content_type  "multipart/mixed"

    inline_attachments = []


    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body   render_message("forward.text.plain.erb",:ticket => ticket, :body => note.full_text, :dropboxes=>note.dropboxes)
      end
      alt.part "text/html" do |html|
        html.body   render_message("forward.text.html.erb",:ticket => ticket, 
                                    :body => generate_body_html(note.full_text_html, inline_attachments, note.account), 
                                    :dropboxes=>note.dropboxes)
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?

    note.all_attachments.each do |a|
      attachment  :content_type => a.content_content_type, 
                  :body => File.read(a.content.to_file.path), 
                  :filename => a.content_file_name
    end
  end

   def send_cc_email(ticket,options={})
    subject       formatted_subject(ticket)
    recipients    options[:cc_emails] unless options[:cc_emails].blank?
    from          ticket.friendly_reply_email
    headers       "Reply-to" => "#{ticket.friendly_reply_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply", "References" => generate_email_references(ticket)
    sent_on       Time.now
    content_type  "multipart/mixed"

    inline_attachments = []

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("send_cc_email.text.plain.erb", :ticket => ticket, :body => ticket.description,:dropboxes=>ticket.dropboxes)
      end
      alt.part "text/html" do |html|
        html.body   render_message("send_cc_email.text.html.erb",:ticket => ticket, 
                                    :body => generate_body_html(ticket.description_html, inline_attachments, ticket.account), 
                                    :dropboxes=>ticket.dropboxes)
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?
    
    ticket.attachments.each do |a|
      attachment  :content_type => a.content_content_type, 
                  :body => File.read(a.content.to_file.path), 
                  :filename => a.content_file_name
    end
  end
  
  def notify_comment(ticket, note , reply_email, options={})
    inline_attachments = []

    subject       formatted_subject(ticket)
    recipients    options[:notify_emails]     
    from          reply_email
    headers       "Reply-to" => "#{reply_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply", "References" => generate_email_references(ticket)
    sent_on       Time.now
    content_type  "multipart/mixed"

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  render_message("notify_comment.text.plain.erb", :ticket => ticket, :note => note , :ticket_url => helpdesk_ticket_url(ticket,:host => ticket.account.host))
      end
      alt.part "text/html" do |html|
        html.body  render_message("notify_comment.text.html.erb", :ticket => ticket, :note => note, 
                                      :body_html => generate_body_html(note.body_html, inline_attachments, note.account), 
                                      :ticket_url => helpdesk_ticket_url(ticket,:host => ticket.account.host))
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?
  end
  
  def email_to_requester(ticket, content, sub=nil)
    subject       (sub.blank? ? formatted_subject(ticket) : sub)
    recipients    ticket.requester.email
    from          ticket.friendly_reply_email
    headers       "Reply-to" => "#{ticket.friendly_reply_email}", "Auto-Submitted" => "auto-replied", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply", "References" => generate_email_references(ticket)
    sent_on       Time.now
    content_type  "multipart/mixed"

    inline_attachments = []

    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  Helpdesk::HTMLSanitizer.plain(content)
      end
      alt.part "text/html" do |html|
        html.body generate_body_html(content, inline_attachments, ticket.account)
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?
  end
  
  def internal_email(ticket, receips, content, sub=nil)
    subject       (sub.blank? ? formatted_subject(ticket) : sub)
    recipients    receips
    from          ticket.friendly_reply_email
    # body          content
    headers       "Reply-to" => "#{ticket.friendly_reply_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply", "References" => generate_email_references(ticket)
    sent_on       Time.now
    content_type  "multipart/mixed"

    inline_attachments = []
    
    part :content_type => "multipart/alternative" do |alt|
      alt.part "text/plain" do |plain|
        plain.body  Helpdesk::HTMLSanitizer.plain(content)
      end
      alt.part "text/html" do |html|
        html.body generate_body_html(content, inline_attachments, ticket.account)
      end
    end

    handle_inline_attachments(inline_attachments) unless inline_attachments.blank?
  end

  private

    def account_bcc_email(ticket)
      ticket.account.bcc_email unless ticket.account.bcc_email.blank?
    end

end
