# encoding: utf-8
class  Helpdesk::TicketNotifier < ActionMailer::Base

  extend ParserUtil
  include Helpdesk::NotifierFormattingMethods

  include Redis::RedisKeys
  include Redis::OthersRedis
  
  layout "email_font"

  def self.notify_by_email(notification_type, ticket, comment = nil)
    e_notification = ticket.account.email_notifications.find_by_notification_type(notification_type)
    if e_notification.agent_notification?
      if (notification_type == EmailNotification::NEW_TICKET)
        language_group_agent_notification(e_notification.agents, e_notification, ticket, comment)
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

  def self.notify_comment(comment)
      ticket = comment.notable
      emails_string = comment.to_emails.join(", ")
      emails = get_email_array emails_string
      agents_list = ticket.account.technicians.where(:email => emails)
      email_notification = ticket.account.email_notifications.find_by_notification_type(EmailNotification::NOTIFY_COMMENT) 
      language_group_agent_notification(agents_list, email_notification, ticket, comment)
  end

  def self.deliver_agent_notification(agent, receips, e_notification, ticket, comment, survey_id = nil)
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
             :subject => a_s_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name).html_safe,
             :survey_id => survey_id,
             :disable_bcc_notification => e_notification.bcc_disabled?,
             :private_comment => comment ? comment.private : false
          }) unless receips.nil?
  end

  def self.language_group_agent_notification(agents_list, e_notification, ticket, comment)
    agents_list.group_by(&:language).each do |language, agents|
      i_receips = agents.map(&:email)
      deliver_agent_notification(agents.first, i_receips, e_notification, ticket, comment)          
    end 
  end

  def self.deliver_requester_notification(requester, receips, e_notification, ticket, comment = nil, non_user = false)
    if e_notification.requester_notification?
        (requester = comment.try(:user) || ticket.requester) if non_user
        notification_template = e_notification.get_requester_template(requester)
        requester_template = notification_template.last
        requester_plain_template = e_notification.get_requester_plain_template(requester)
        requester_subject = notification_template.first

      r_template = Liquid::Template.parse(requester_template.gsub("{{ticket.status}}","{{ticket.requester_status_name}}")) 
      r_plain_template = Liquid::Template.parse(requester_plain_template.gsub("{{ticket.status}}","{{ticket.requester_status_name}}").gsub("{{ticket.description}}", "{{ticket.description_text}}"))
      r_s_template = Liquid::Template.parse(requester_subject.gsub("{{ticket.status}}","{{ticket.requester_status_name}}"))
      html_version = r_template.render('ticket' => ticket, 
                  'helpdesk_name' => ticket.account.portal_name, 'comment' => comment).html_safe
      plain_version = r_plain_template.render('ticket' => ticket, 
                  'helpdesk_name' => ticket.account.portal_name, 'comment' => comment).html_safe
      params = { :ticket => ticket,
               :notification_type => e_notification.notification_type,
               :receips => receips,
               :email_body_plain => plain_version,
               :email_body_html => html_version,
               :subject => r_s_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name).html_safe,
               :disable_bcc_notification => e_notification.bcc_disabled?}
      deliver_email_notification(params) unless receips.nil?
    end
  end

  def self.send_cc_email(ticket, comment=nil, options={})
    if comment
      cc_emails_string = ticket.cc_email[:reply_cc].join(",") if (ticket.cc_email.present? && ticket.cc_email[:reply_cc].present?)
      e_notification = ticket.account.email_notifications.find_by_notification_type(EmailNotification::PUBLIC_NOTE_CC)
    else
      cc_emails_string = options[:cc_emails].join(",") if (options && options[:cc_emails])
      e_notification = ticket.account.email_notifications.find_by_notification_type(EmailNotification::NEW_TICKET_CC)
    end
    return if cc_emails_string.blank?
    cc_emails = get_email_array cc_emails_string
    db_users = ticket.account.users.where(:email => cc_emails)
    db_users_email = db_users.map(&:email).map(&:downcase)
    non_db_user_ccs = cc_emails - db_users_email
    db_users.group_by(&:language).each do |language, users|
      i_receips = users.map(&:email).join(", ")
      deliver_requester_notification(users.first, i_receips, e_notification, ticket, comment)
    end
    deliver_requester_notification(nil, non_db_user_ccs.join(", "), e_notification, ticket, comment, true) unless non_db_user_ccs.empty?
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

  def message_key(account_id, message_id)
    EMAIL_TICKET_ID % {:account_id => account_id, :message_id => message_id}
  end

  def email_notification(params)
    ActionMailer::Base.set_mailbox params[:ticket].reply_email_config.smtp_mailbox

    bcc_email = params[:disable_bcc_notification] ? "" : validate_emails(account_bcc_email(params[:ticket]),
                                                                         params[:ticket])
    receips = validate_emails(params[:receips], params[:ticket])
    from_email = validate_emails(params[:ticket].friendly_reply_email, params[:ticket])
    return if receips.empty? || from_email.empty?

    private_tag = params[:private_comment] ? "private-" : ""

    #Store message ID in Redis for new ticket notifications to improve threading
    message_id = "#{Mail.random_tag}.#{::Socket.gethostname}@#{private_tag}notification.freshdesk.com"

    headers = email_headers(params[:ticket], message_id, true, private_tag.present?).merge({
      :subject    =>  params[:subject],
      :to         =>  receips,
      :from       =>  from_email,
      :bcc        =>  bcc_email,
      "Reply-To"  =>  "#{from_email}"
    })

    inline_attachments   = []
    @ticket              = params[:ticket]
    @body                = params[:email_body_plain]
    @cloud_files           = params[:cloud_files]
    if(params[:notification_type] == EmailNotification::PREVIEW_EMAIL_VERIFICATION)
      @survey_feedback_preview = true
    else
      @survey_feedback_preview = false
    end

    if params[:ticket].account.new_survey_enabled?
      @survey_handle = CustomSurvey::SurveyHandle.create_handle_for_notification(params[:ticket], params[:notification_type], params[:survey_id], @survey_feedback_preview)
    else
      @survey_handle = SurveyHandle.create_handle_for_notification(params[:ticket], params[:notification_type])
    end

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

    if params[:notification_type] == EmailNotification::NEW_TICKET and params[:ticket].source != Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
      set_others_redis_key(message_key(params[:ticket].account_id, message_id),
                           "#{params[:ticket].display_id}:#{message_id}",
                           86400*7) unless message_id.nil?
      update_ticket_header_info(params[:ticket].id, message_id)
    end
  end

  def reply(ticket, note , options={})
    email_config = (note.account.email_configs.find_by_id(note.email_config_id) || ticket.reply_email_config)
    ActionMailer::Base.set_mailbox email_config.smtp_mailbox

    to_emails = validate_emails(note.to_emails, note)
    bcc_emails = validate_emails(note.bcc_emails, note)
    from_email = validate_emails(note.from_email, note)
    return if from_email.empty? || to_emails.empty?

    options = {} unless options.is_a?(Hash) 
    headers = email_headers(ticket, nil, false).merge({
      :subject    =>  formatted_subject(ticket),
      :to         =>  to_emails,
      :bcc        =>  bcc_emails,
      :from       =>  from_email,
      "Reply-To"  =>  "#{from_email}"
    })

    headers[:cc] = validate_emails(note.cc_emails, note) unless options[:include_cc].blank?

    inline_attachments = []

    @body = note.full_text
    @body_html = generate_body_html(note.full_text_html)
    @note = note 
    @cloud_files = note.cloud_files    
    @include_quoted_text = options[:quoted_text]
    @surveymonkey_survey =  Integrations::SurveyMonkey.survey(options[:include_surveymonkey_link], ticket, note.user)
    @ticket = ticket
    @account = note.account    

    if ticket.account.new_survey_enabled?
       @survey_handle = CustomSurvey::SurveyHandle.create_handle(ticket, note, options[:send_survey])
    else
       @survey_handle = SurveyHandle.create_handle(ticket, note, options[:send_survey])
    end

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

    to_emails = validate_emails(note.to_emails - [note.account.kbase_email], note)
    from_email = validate_emails(note.from_email, note)
    return if from_email.empty? || to_emails.empty?
    bcc_emails = validate_emails(note.bcc_emails, note)
    cc_emails = validate_emails(note.cc_emails, note)
    
    headers = email_headers(ticket, nil, false).merge({
      :subject    =>  fwd_formatted_subject(ticket),
      :to         =>  to_emails,
      :cc         =>  cc_emails,
      :bcc        =>  bcc_emails,
      :from       =>  from_email,
      "Reply-To"  =>  "#{from_email}"
    })

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

  def reply_to_forward(ticket, note, options={})
    email_config = (note.account.email_configs.find_by_id(note.email_config_id) || ticket.reply_email_config)
    ActionMailer::Base.set_mailbox email_config.smtp_mailbox

    to_emails = validate_emails(note.to_emails, note)
    from_email = validate_emails(note.from_email, note)
    return if from_email.empty? || to_emails.empty?
    bcc_emails = validate_emails(note.bcc_emails, note)
    cc_emails = validate_emails(note.cc_emails, note)
    
    headers = email_headers(ticket, nil, false).merge({
      :subject    =>  formatted_subject(ticket),
      :to         =>  to_emails,
      :cc         =>  cc_emails,
      :bcc        =>  bcc_emails,
      :from       =>  from_email,
      "Reply-To"  =>  "#{from_email}"
    })

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
      part.text { render "reply_to_forward.text.plain" }
      part.html { render "reply_to_forward.text.html" }
    end.deliver
  end
  
  def email_to_requester(ticket, content, sub=nil)
    ActionMailer::Base.set_mailbox ticket.reply_email_config.smtp_mailbox

    headers   = email_headers(ticket, nil).merge({
      :subject    =>  (sub.blank? ? formatted_subject(ticket) : sub),
      :to         =>  ticket.from_email,
      :from       =>  ticket.friendly_reply_email,
      :sent_on    =>  Time.now,
      "Reply-To"  =>  "#{ticket.friendly_reply_email}"
    })

    inline_attachments = []
    @body = Helpdesk::HTMLSanitizer.plain(content)
    @body_html = generate_body_html(content)
    @account = ticket.account
    @ticket = ticket

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, content, ticket.account)
    end

    mail(headers) do |part|
      part.text { render "email_to_requester.text.plain" }
      part.html { render "email_to_requester.text.html" }
    end.deliver

  end
  
  def internal_email(ticket, receips, content, sub=nil)
    ActionMailer::Base.set_mailbox ticket.reply_email_config.smtp_mailbox

    headers = email_headers(ticket, nil).merge({
      :subject    =>  (sub.blank? ? formatted_subject(ticket) : sub),
      :to         =>  receips,
      :from       =>  ticket.friendly_reply_email,
      :sent_on    =>  Time.now,
      "Reply-To"  =>  "#{ticket.friendly_reply_email}"
    })

    inline_attachments = []
    @body = Helpdesk::HTMLSanitizer.plain(content)
    @body_html = generate_body_html(content)
    @account = ticket.account
    @ticket = ticket

    if attachments.present? && attachments.inline.present?
      handle_inline_attachments(attachments, content, ticket.account)
    end

    mail(headers) do |part|
      part.text { render "internal_email.text.plain" }
      part.html { render "internal_email.text.html" }
    end.deliver

  end

  def notify_outbound_email(ticket)
    ActionMailer::Base.set_mailbox ticket.reply_email_config.smtp_mailbox

    from_email = if ticket.account.features?(:personalized_email_replies)
      ticket.friendly_reply_email_personalize(ticket.responder_name)
    else
      ticket.friendly_reply_email
    end

    from_email = validate_emails(from_email, ticket)
    to_email = validate_emails(ticket.from_email, ticket)
    return if from_email.empty? || to_email.empty?
    cc_emails = validate_emails(ticket.cc_email[:cc_emails], ticket)
    bcc_emails = validate_emails(account_bcc_email(ticket), ticket)

    #Store message ID in Redis for outbound email to improve threading
    message_id = "#{Mail.random_tag}.#{::Socket.gethostname}@outbound-email.freshdesk.com"

    headers = email_headers(ticket, message_id, false).merge({
      :subject    =>  ticket.subject,
      :to         =>  to_email,
      :from       =>  from_email,
      :cc         =>  cc_emails,
      :bcc        =>  bcc_emails,
      "Reply-To"  =>  from_email
    })

    inline_attachments   = []
    @account = ticket.account
    @ticket = ticket
    @cloud_files= ticket.cloud_files
    
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
      part.text { render "notify_outbound_email.text.plain" }
      part.html { render "notify_outbound_email.text.html" }
    end.deliver

    set_others_redis_key(message_key(ticket.account_id, message_id),
                         "#{ticket.display_id}:#{message_id}",
                         86400*7) unless message_id.nil?
    update_ticket_header_info(ticket.id, message_id)
  end

  private
    def account_bcc_email(ticket)
      ticket.account.bcc_email unless ticket.account.bcc_email.blank?
    end

    def update_ticket_header_info(ticket_id, ticket_message_id)
      ticket = Account.current.tickets.find_by_id(ticket_id) if ticket_id and Account.current
      if ticket and ticket_message_id.present?
        header_info = (ticket.header_info || {})
        #Update header info only if not present
        if header_info[:message_ids].blank?
          header_info[:message_ids] = [ticket_message_id]
          ticket.header_info = header_info
          ticket.save
        end
      end
    end

    def email_headers(ticket, message_id, auto_submitted=true, suppress_references=false)
      #default message id
      message_id = message_id || "#{Mail.random_tag}.#{::Socket.gethostname}@email.freshdesk.com"

      headers = {
        "Message-ID"  =>  "<#{message_id}>",
        :sent_on      =>  Time.now
      }

      if auto_submitted
        headers.merge!({
          "Auto-Submitted"            =>  "auto-generated",
          "X-Auto-Response-Suppress"  =>  "DR, RN, OOF, AutoReply"
        })
      end

      #Don't send empty headers
      #Don't send 'references' header for private notification
      if suppress_references
        set_others_redis_key(message_key(ticket.account_id, message_id),
                         "#{ticket.display_id}:#{message_id}",
                         86400*7) unless message_id.nil?
      else
        references = generate_email_references(ticket)
        headers["References"] = references unless references.blank?

        reply_to = in_reply_to(ticket)
        headers["In-Reply-To"] = reply_to unless reply_to.blank?
      end

      headers
    end

    def message_key(account_id, message_id)
      EMAIL_TICKET_ID % {:account_id => account_id, :message_id => message_id}
    end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias 
end
