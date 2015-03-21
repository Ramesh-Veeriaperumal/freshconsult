# encoding: utf-8
class  Helpdesk::TicketNotifier < ActionMailer::Base
  include Helpdesk::NotifierFormattingMethods
  
  layout "email_font"

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
             :receips => ticket.from_email,
             :email_body_plain => plain_version,
             :email_body_html => html_version,
             :subject => r_s_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name).html_safe}
      if(notification_type == EmailNotification::NEW_TICKET and ticket.source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone])
        params[:attachments] = ticket.attachments
        params[:cloud_files] = ticket.cloud_files
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
    ActionMailer::Base.set_mailbox params[:ticket].reply_email_config.smtp_mailbox
    
    headers = {
      :subject                   => params[:subject],
      :to                        => params[:receips],
      :from                      => params[:ticket].friendly_reply_email,
      :bcc                       => account_bcc_email(params[:ticket]),
      "Reply-to"                 => "#{params[:ticket].friendly_reply_email}", 
      "Auto-Submitted"           => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply", 
      "References"               => generate_email_references(params[:ticket]),
      :sent_on                   => Time.now
    }



    inline_attachments   = []
    @ticket              = params[:ticket] 
    @body                = params[:email_body_plain]
    @cloud_files           = params[:cloud_files]
    @survey_handle       = SurveyHandle.create_handle_for_notification(
                            params[:ticket],params[:notification_type]
                          )
    @surveymonkey_survey = Integrations::SurveyMonkey.survey_for_notification(
                            params[:notification_type], params[:ticket]
                          )
    @body_html           = generate_body_html(params[:email_body_html])
    @account             = params[:ticket].account
    
    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, params[:email_body_html], params[:ticket].account)
    end

    params[:attachments].each do |a|
      attachments[a.content_file_name] = {
        :mime_type => a.content_content_type,
        :content => File.read(a.content.to_file.path, :mode => "rb")
      } 
    end if params[:attachments].present?

    mail(headers) do |part|
      part.text { render "email_notification.text.plain" }
      part.html { render "email_notification.text.html" }
    end.deliver
  end

  def reply(ticket, note , options={})
    email_config = (note.account.email_configs.find_by_id(note.email_config_id) || ticket.reply_email_config)
    ActionMailer::Base.set_mailbox email_config.smtp_mailbox

    options = {} unless options.is_a?(Hash) 
    
    headers = {
      :subject                       => formatted_subject(ticket),
      :to                            => note.to_emails,
      :bcc                           => note.bcc_emails,
      :from                          => note.from_email,
      :sent_on                       => Time.now,
      "Reply-to"                     => "#{note.from_email}", 
      "Auto-Submitted"               => "auto-generated", 
      "X-Auto-Response-Suppress"     => "DR, RN, OOF, AutoReply", 
      "References"                   => generate_email_references(ticket)
    }

    headers[:cc] = note.cc_emails unless options[:include_cc].blank?

    inline_attachments = []

    @body = note.full_text
    @body_html = generate_body_html(note.full_text_html)
    @note = note 
    @cloud_files = note.cloud_files
    @survey_handle = SurveyHandle.create_handle(ticket, note, options[:send_survey])
    @include_quoted_text = options[:quoted_text]
    @surveymonkey_survey =  Integrations::SurveyMonkey.survey(options[:include_surveymonkey_link], ticket, note.user)
    @ticket = ticket
    @account = note.account

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, note.full_text_html, note.account)
    end
    note.all_attachments.each do |a|
      attachments[a.content_file_name] = {
        :mime_type => a.content_content_type, 
        :content => File.read(a.content.to_file.path, :mode => "rb")
      }
    end

    mail(headers) do |part|
      part.text { render "reply.text.plain" }
      part.html { render "reply.text.html" }
    end.deliver
  end
  
  def forward(ticket, note, options={})
    email_config = (note.account.email_configs.find_by_id(note.email_config_id) || ticket.reply_email_config)
    ActionMailer::Base.set_mailbox email_config.smtp_mailbox
    
    headers = {
      :subject                                => fwd_formatted_subject(ticket),
      :to                                     => note.to_emails,
      :cc                                     => note.cc_emails,
      :bcc                                    => note.bcc_emails,
      :from                                   => note.from_email,
      :sent_on                                => Time.now,
      "Reply-to"                              => "#{note.from_email}", 
      "Auto-Submitted"                        => "auto-generated", 
      "X-Auto-Response-Suppress"              => "DR, RN, OOF, AutoReply", 
      "References"                            => generate_email_references(ticket)
    }

    inline_attachments = []
    @ticket = ticket
    @body = note.full_text
    @cloud_files= note.cloud_files
    @body_html = generate_body_html(note.full_text_html)
    @account = note.account

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, note.full_text_html, note.account)
    end
    self.class.trace_execution_scoped(['Custom/Helpdesk::TicketNotifier/read_binary_attachment']) do
      note.all_attachments.each do |a|
        attachments[a.content_file_name] = {
          :mime_type => a.content_content_type, 
          :content => File.read(a.content.to_file.path, :mode => "rb")
        }
      end
    end
    mail(headers) do |part|
      part.text { render "forward.text.plain" }
      part.html { render "forward.text.html" }
    end.deliver
  end

  def send_cc_email(ticket,options={})
    ActionMailer::Base.set_mailbox ticket.reply_email_config.smtp_mailbox

    headers = {
      :subject                        => formatted_subject(ticket),
      :from                           => ticket.friendly_reply_email,
      :sent_on                        => Time.now,
      "Reply-to"                      => "#{ticket.friendly_reply_email}", 
      "Auto-Submitted"                => "auto-generated", 
      "X-Auto-Response-Suppress"      => "DR, RN, OOF, AutoReply", 
      "References"                    => generate_email_references(ticket)
    }
    # TODO-RAILS3 why the hell all this code cann't top invoking this method if the cc_emails is blank
    headers[:to] = options[:cc_emails] unless options[:cc_emails].blank?

    inline_attachments = []
    @ticket = ticket 
    @body = ticket.description
    @cloud_files = ticket.cloud_files
    @body_html = generate_body_html(ticket.description_html)
    @account = ticket.account

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, ticket.description_html, ticket.account)
    end

    self.class.trace_execution_scoped(['Custom/Helpdesk::TicketNotifier/read_binary_attachment']) do
      ticket.attachments.each do |a|
        attachments[ a.content_file_name] = { 
          :mime_type => a.content_content_type, 
          :content => File.read(a.content.to_file.path, :mode => "rb")
        }
      end
    end
    mail(headers) do |part|
      part.text { render "send_cc_email.text.plain" }
      part.html { render "send_cc_email.text.html" }
    end.deliver
  end
  
  def notify_comment(ticket, note , reply_email, options={})
    inline_attachments = []

    email_config = (note.account.email_configs.find_by_id(note.email_config_id) || ticket.reply_email_config)
    ActionMailer::Base.set_mailbox email_config.smtp_mailbox

    headers = {
      :subject                        => formatted_subject(ticket),
      :to                             => options[:notify_emails],
      :from                           => reply_email,
      :sent_on                        => Time.now,
      "Reply-to"                      => "#{reply_email}", 
      "Auto-Submitted"                => "auto-generated", 
      "X-Auto-Response-Suppress"      => "DR, RN, OOF, AutoReply", 
      "References"                    => generate_email_references(ticket)
    }

    @ticket_url = helpdesk_ticket_url(ticket,:host => ticket.account.host, :protocol => ticket.url_protocol)
    @body_html = generate_body_html(note.body_html)
    @note = note
    @ticket = ticket
    @account = note.account
    
    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, note.body_html, note.account)
    end

    note.all_attachments.each do |a|
      attachments[a.content_file_name] = {
        :mime_type => a.content_content_type, 
        :content => File.read(a.content.to_file.path, :mode => "rb")
      }
    end

    mail(headers) do |part|
      part.text { render "notify_comment.text.plain" }
      part.html { render "notify_comment.text.html" }
    end.deliver
  end
  
  def email_to_requester(ticket, content, sub=nil)
    ActionMailer::Base.set_mailbox ticket.reply_email_config.smtp_mailbox
    
    headers   = {
      :subject                      => (sub.blank? ? formatted_subject(ticket) : sub),
      :to                           => ticket.from_email,
      :from                         => ticket.friendly_reply_email,
      :sent_on                      => Time.now,
      "Reply-to"                    => "#{ticket.friendly_reply_email}", 
      "Auto-Submitted"              => "auto-replied", 
      "X-Auto-Response-Suppress"    => "DR, RN, OOF, AutoReply", 
      "References"                  => generate_email_references(ticket)
    }
    inline_attachments = []
    @body = Helpdesk::HTMLSanitizer.plain(content)
    @body_html = generate_body_html(content)
    @account = ticket.account

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, content, ticket.account)
    end

    mail(headers) do |part|
      part.text { @body }
      part.html { @body_html }
    end.deliver
  end
  
  def internal_email(ticket, receips, content, sub=nil)
    ActionMailer::Base.set_mailbox ticket.reply_email_config.smtp_mailbox
    
    headers     =  {
      :subject                        => (sub.blank? ? formatted_subject(ticket) : sub),
      :to                             => receips,
      :from                           => ticket.friendly_reply_email,
      :sent_on                        => Time.now,
      "Reply-to"                      => "#{ticket.friendly_reply_email}", 
      "Auto-Submitted"                => "auto-generated", 
      "X-Auto-Response-Suppress"      => "DR, RN, OOF, AutoReply", 
      "References"                    => generate_email_references(ticket)
    }
    inline_attachments = []
    @body = Helpdesk::HTMLSanitizer.plain(content)
    @body_html = generate_body_html(content)
    @account = ticket.account

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, content, ticket.account)
    end

    mail(headers) do |part|
      part.text { @body }
      part.html { @body_html }
    end.deliver
  end

  private
    def account_bcc_email(ticket)
      ticket.account.bcc_email unless ticket.account.bcc_email.blank?
    end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias 
end