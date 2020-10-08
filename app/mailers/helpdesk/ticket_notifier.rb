# encoding: utf-8
class  Helpdesk::TicketNotifier < ActionMailer::Base

  require 'freemail'

  extend ParserUtil
  include EmailHelper
  include Email::EmailService::EmailDelivery
  include Helpdesk::NotifierFormattingMethods

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Helpdesk::SpamAccountConstants
  
  layout "email_font"

  def suppression_list_alert(admin,dropped_address = nil,display_id)
    begin
      email_config = Account.current.primary_email_config
      configure_email_config email_config
      headers = {
        :to       => "support@freshdesk.com",
        :from     => admin.email,
        :subject  => I18n.t('email_failure.suppression_list_alert.subject'),
        :sent_on  => Time.now
      }
      current_account     = Account.current
      @account_name       = current_account.name
      @account_url        = "#{current_account.url_protocol}://#{current_account.full_domain}"
      @dropped_address    = dropped_address
      @agent_name         = admin.name
      @ticket_display_id  = display_id
      headers.merge!(make_header(@ticket_display_id, nil, current_account.id, "Supression List Alert"))
      mail(headers) do |part|
        part.html { render "suppression_list_alert" }
      end.deliver
    ensure 
      remove_email_config
    end
  end

  def self.notify_by_email(notification_type, ticket, comment = nil, opts = {})
    internal_notification = opts[:internal_notification]
    e_notification = fetch_email_notification(ticket, notification_type)
    begin
        if e_notification.agent_notification?
          if (notification_type == EmailNotification::NEW_TICKET)
            language_group_agent_notification(e_notification.agents, e_notification, ticket, comment)
          else  
            i_receips = internal_receips(e_notification, ticket, internal_notification)
            agent = internal_notification ? ticket.internal_agent : ticket.responder
            deliver_agent_notification(agent, i_receips, e_notification, ticket, comment, nil, opts)
          end 
        end
    rescue => e
      Rails.logger.info "Exception while trying to send agent notification , message :#{e.message} - #{e.backtrace}"
    end
    if e_notification.requester_notification? and !ticket.out_of_office?
      requester_template = e_notification.get_requester_template(ticket.requester)
      requester_plain_template = e_notification.get_requester_plain_template(ticket.requester)
      r_template = Liquid::Template.parse(requester_template.last.gsub("{{ticket.status}}","{{ticket.requester_status_name}}")) 
      r_plain_template = Liquid::Template.parse(requester_plain_template.gsub("{{ticket.status}}","{{ticket.requester_status_name}}").gsub("{{ticket.description}}", "{{ticket.description_text}}"))
      r_s_template = Liquid::Template.parse(requester_template.first.gsub("{{ticket.status}}","{{ticket.requester_status_name}}"))
      template_params = construct_template_params(ticket, comment, opts)
      html_version = r_template.render(template_params).html_safe
      plain_version = r_plain_template.render(template_params).html_safe

      params = { :ticket => ticket,
             :notification_type => notification_type,
             :receips => ticket.from_email,
             :email_body_plain => plain_version,
             :email_body_html => html_version,
             :subject => r_s_template.render('ticket' => ticket.to_liquid, 'helpdesk_name' => ticket.account.helpdesk_name).html_safe}
      if(notification_type == EmailNotification::NEW_TICKET and ticket.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:phone])
        params[:attachments] = ticket.all_attachments
        params[:cloud_files] = ticket.cloud_files
      end
      params[:note_id] = comment.id unless (comment.nil?)
      deliver_email_notification(params) if ticket.requester_has_email?
    end
  end

  def self.notify_comment(comment)
      ticket = comment.notable
      emails_string = comment.to_emails.join(", ")
      emails = get_email_array emails_string
      agents_list = ticket.account.technicians.where(:email => emails)
      email_notification = if comment.source == EmailNotification::SOURCE_IS_AUTOMAION_RULE
                             ticket.account.email_notifications.find_by_notification_type(EmailNotification::AUTOMATED_PRIVATE_NOTES)
                           else
                             ticket.account.email_notifications.find_by_notification_type(EmailNotification::NOTIFY_COMMENT)
                           end
      language_group_agent_notification(agents_list, email_notification, ticket, comment)
  end

  def self.deliver_agent_notification(agent, receips, e_notification, ticket, comment, survey_id = nil, opts = {})
      internal_notification = opts[:internal_notification]
      agent_template = internal_notification ? e_notification.get_internal_agent_template(agent) : e_notification.get_agent_template(agent)
      agent_plain_template = internal_notification ? e_notification.get_internal_agent_plain_template(agent) : e_notification.get_agent_plain_template(agent)
      a_template = Liquid::Template.parse(agent_template.last) 
      a_plain_template = Liquid::Template.parse(agent_plain_template.gsub("{{ticket.description}}", "{{ticket.description_text}}"))
      a_s_template = Liquid::Template.parse(agent_template.first) 
      html_version = a_template.render('ticket' => ticket.to_liquid, 
                'helpdesk_name' => ticket.account.helpdesk_name, 'comment' => comment,'account_name' => ticket.account.helpdesk_name.to_liquid).html_safe
      plain_version = a_plain_template.render('ticket' => ticket.to_liquid, 
                'helpdesk_name' => ticket.account.helpdesk_name, 'comment' => comment,'account_name' => ticket.account.helpdesk_name.to_liquid).html_safe
      headers = { :ticket => ticket,
       :notification_type => e_notification.notification_type,
       :receips => receips,
       :email_body_plain => plain_version,
       :email_body_html => html_version,
       :subject => a_s_template.render('ticket' => ticket.to_liquid, 'helpdesk_name' => ticket.account.helpdesk_name).html_safe,
       :survey_id => survey_id,
       :disable_bcc_notification => e_notification.bcc_disabled?,
       :private_comment => comment ? comment.private : false,
      }
      headers[:note_id] = comment.id unless comment.nil?
      deliver_email_notification(headers) unless receips.nil?
  end

  def self.language_group_agent_notification(agents_list, e_notification, ticket, comment)
    agents_list.group_by(&:language).each do |language, agents|
      i_receips = agents.map(&:email)
      deliver_agent_notification(agents.first, i_receips, e_notification, ticket, comment)          
    end 
  end

  #The address set with envelope_to will get the mail , irrespective of whatever that is set in to_emails. Use envelope_to with 
  #this limitation in mind. 
  def self.deliver_requester_notification(requester, to_emails, e_notification, ticket, comment = nil, non_user = false, cc_mails = nil, smtp_envelope_to = nil)
    if e_notification.requester_notification?
        (requester = comment.try(:user) || ticket.requester) if non_user
        notification_template = e_notification.get_requester_template(requester)
        requester_template = notification_template.last
        requester_plain_template = e_notification.get_requester_plain_template(requester)
        requester_subject = notification_template.first

      r_template = Liquid::Template.parse(requester_template.gsub("{{ticket.status}}","{{ticket.requester_status_name}}")) 
      r_plain_template = Liquid::Template.parse(requester_plain_template.gsub("{{ticket.status}}","{{ticket.requester_status_name}}").gsub("{{ticket.description}}", "{{ticket.description_text}}"))
      r_s_template = Liquid::Template.parse(requester_subject.gsub("{{ticket.status}}","{{ticket.requester_status_name}}"))
      template_params = construct_template_params(ticket, comment)
      html_version = r_template.render(template_params).html_safe
      plain_version = r_plain_template.render(template_params).html_safe
      params = { :ticket => ticket,
               :notification_type => e_notification.notification_type,
               :receips => to_emails,
               :email_body_plain => plain_version,
               :email_body_html => html_version,
               :subject => r_s_template.render('ticket' => ticket.to_liquid, 'helpdesk_name' => ticket.account.helpdesk_name).html_safe,
               :disable_bcc_notification => e_notification.bcc_disabled?}
                  
      if !cc_mails.nil?
         params[:cc_mails] = cc_mails
      end
      
      if !smtp_envelope_to.nil?
        params[:smtp_envelope_to] = smtp_envelope_to
      end
      
      if(e_notification.notification_type == EmailNotification::NEW_TICKET_CC and ticket.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:phone])
         params[:attachments] = ticket.attachments
         params[:cloud_files] = ticket.cloud_files
      end
      params[:note_id] = comment.id unless comment.nil?
      deliver_email_notification(params) unless to_emails.nil?
    end
  end

  def self.send_cc_email(ticket, comment=nil, options={})
    cc_emails = []
    if comment
      cc_emails = ticket.cc_email[:reply_cc] if (ticket.cc_email.present? && ticket.cc_email[:reply_cc].present?)
      e_notification = ticket.account.email_notifications.find_by_notification_type(EmailNotification::PUBLIC_NOTE_CC)
    else
      cc_emails = options[:cc_emails] if (options && options[:cc_emails])
      e_notification = ticket.account.email_notifications.find_by_notification_type(EmailNotification::NEW_TICKET_CC)
    end

    cc_emails.concat(options[:additional_emails]) if options[:additional_emails].present?
    ignore_emails = (options[:ignore_emails] || []) + [ticket.account.kbase_email]
    cc_emails = fetch_valid_emails(cc_emails, {:ignore_emails => ignore_emails}) if ignore_emails.present?
    
    return if cc_emails.to_a.count == 0

    #ignoring support emails
    cc_emails  = get_email_array cc_emails.join(",")
    support_emails_in_cc = ticket.account.all_email_configs.pluck(:reply_email)
    cc_emails = cc_emails - support_emails_in_cc

    return if cc_emails.to_a.count == 0

    db_users = ticket.account.users.where(:email => cc_emails)
    db_users_email = db_users.map(&:email).map(&:downcase)
    non_db_user_ccs = cc_emails - db_users_email
    db_users.group_by(&:language).each do |language, users|
      i_receips = users.map(&:email).join(", ")
       
        ##Adding the left over CCs to facilitate reply to all##
       
       refined_receipts=get_email_array i_receips
       left_out_ccs=cc_emails - refined_receipts
      deliver_requester_notification(users.first, i_receips, e_notification, ticket, comment,false,left_out_ccs,i_receips)
    end
    
    ##Adding the left over CCs to facilitate reply to all##
    
    
    refined_receipts=get_email_array non_db_user_ccs if !non_db_user_ccs.empty?
    left_out_ccs=cc_emails - refined_receipts if !refined_receipts.nil?
    
    deliver_requester_notification(nil, non_db_user_ccs.join(", "), e_notification, ticket, comment, true,left_out_ccs,non_db_user_ccs) unless non_db_user_ccs.empty?
  end

  def self.internal_receips(e_notification, ticket, internal_notification)
    if(e_notification.notification_type == EmailNotification::TICKET_ASSIGNED_TO_GROUP)
      group = internal_notification ? ticket.internal_group : ticket.group
      group.agent_emails if group.present? and !group.agent_emails.empty?
    else
      agent = internal_notification ? ticket.internal_agent : ticket.responder
      agent.email if agent.present?
    end
  end

  def message_key(account_id, message_id)
    EMAIL_TICKET_ID % {:account_id => account_id, :message_id => message_id}
  end

  def email_notification(params)
    begin
      configure_email_config params[:ticket].friendly_reply_email_config
      
      bcc_email = params[:disable_bcc_notification] ? "" : validate_emails(account_bcc_email(params[:ticket]),
                                                                           params[:ticket])
      receips = validate_emails(params[:receips], params[:ticket])
      from_email = validate_emails(params[:ticket].friendly_reply_email, params[:ticket])
      return if receips.empty? || from_email.empty?

      private_tag = params[:private_comment] ? "private-" : ""
      note_id     = params[:note_id] ? params[:note_id] : nil

      #Store message ID in Redis for new ticket notifications to improve threading
      message_id = "#{Mail.random_tag}.#{::Socket.gethostname}@#{private_tag}notification.freshdesk.com"
      
      headers = email_headers(params[:ticket], message_id, true, private_tag.present?).merge({
        :subject    =>  params[:subject],
        :to         =>  receips,
        :from       =>  from_email,
        :bcc        =>  bcc_email,
        "Reply-To"  =>  "#{from_email}"
        })

      headers.merge!(make_header(params[:ticket].display_id, note_id, params[:ticket].account_id, params[:notification_type]))
      headers.merge!({"X-FD-Email-Category" => params[:ticket].friendly_reply_email_config.category}) if params[:ticket].friendly_reply_email_config.category.present?
      inline_attachments   = []
      @ticket              = params[:ticket]
      @body                = params[:email_body_plain]
      @cloud_files           = params[:cloud_files]
      

      if params[:ticket].account.new_survey_enabled?
        @survey_handle = CustomSurvey::SurveyHandle.create_handle_for_notification(params[:ticket], params[:notification_type], params[:survey_id])
        @survey_language = Language.find_by_code(params[:ticket].requester_language)
        @translated_survey = @survey_handle.survey.translation_record(@survey_language) if @survey_handle && @survey_language.present?
      else
        @survey_handle = SurveyHandle.create_handle_for_notification(params[:ticket], params[:notification_type])
      end

      @surveymonkey_survey = Integrations::SurveyMonkey.survey_for_notification(
                              params[:notification_type], params[:ticket]
                            )
      @body_html           = generate_body_html(params[:email_body_html])
      @account             = params[:ticket].account
      @attachment_files    = params[:attachments]

      if attachments.present? && attachments.inline.present?
        handle_inline_attachments(attachments, params[:email_body_html], params[:ticket].account)
      end

      unless @account.secure_attachments_enabled?
        add_attachments if @attachment_files.present?
      end

      if !params[:cc_mails].nil?
         headers[:cc] = params[:cc_mails].join(", ")
      end
      email_config = params[:ticket].friendly_reply_email_config
      if via_email_service?(params[:ticket].account, email_config)
        deliver_email(headers, regular_attachments, "email_notification")
      else
        ##Setting the templates for mail usage###
        message = mail(headers) do |part|
          part.text { render "email_notification.text.plain" }
          part.html { render "email_notification.text.html" }
        end
        
        ##Envelope is set for mail cc case. 
        #Only the people in envelope receive the mail and rest go in cc. 
        #Facilitates reply-to all feature
        if !params[:smtp_envelope_to].nil?
          envelope_mail  = validate_emails(params[:smtp_envelope_to], params[:ticket])
          if !envelope_mail.nil?
            message.smtp_envelope_to=envelope_mail
          end
        end

        message.deliver  
      end
    ensure 
      remove_email_config
    end

    if params[:notification_type] == EmailNotification::NEW_TICKET and params[:ticket].source != Account.current.helpdesk_sources.ticket_source_keys_by_token[:email]
      set_others_redis_key(message_key(params[:ticket].account_id, message_id),
                           "#{params[:ticket].display_id}:#{message_id}",
                           86400*7) unless message_id.nil?
      update_ticket_header_info(params[:ticket].id, message_id)
    end
  end

  def reply(ticket, note , options={})
    check_spam_email(ticket, note)
    email_config = (note.account.email_configs.find_by_reply_email(extract_email(note.from_email)) || ticket.reply_email_config)
    begin
      configure_email_config email_config
      to_emails = validate_emails(note.to_emails, note)
      bcc_emails = validate_emails(note.bcc_emails, note)
      from_email = validate_emails(note.from_email, note)
      if from_email.empty? || to_emails.empty?
        if from_email.empty?
          Rails.logger.info "Reply Email Not Sent as there is no from_email. Note_id: #{note.id}, Ticket_id: #{ticket.id}"
        else
          Rails.logger.info "Reply Email Not Sent as there is no to_email. Note_id: #{note.id}, Ticket_id: #{ticket.id}"
        end
        return
      end

      options = {} unless options.is_a?(Hash)

      headers = email_headers(ticket, nil, false, false, true).merge({
        :subject    =>  formatted_subject(ticket),
        :to         =>  to_emails,
        :bcc        =>  bcc_emails,
        :from       =>  from_email,
        "Reply-To"  =>  "#{from_email}"
      })

      headers.merge!(make_header(ticket.display_id, note.id, ticket.account_id, "Reply"))
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
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
      @attachment_files = note.all_attachments

      unless ticket.parent_ticket.present?
        if ticket.account.new_survey_enabled?
          @survey_handle = CustomSurvey::SurveyHandle.create_handle(ticket, note, options[:send_survey])
          @survey_language = Language.find_by_code(ticket.requester_language)
          @translated_survey = @survey_handle.survey.translation_record(@survey_language) if @survey_handle && @survey_language.present?
        else
           @survey_handle = SurveyHandle.create_handle(ticket, note, options[:send_survey])
        end
      end

      if attachments.present? && attachments.inline.present?
        handle_inline_attachments(attachments, note.full_text_html, note.account)
      end

      add_attachments unless @account.secure_attachments_enabled?
      mail(headers) do |part|
        part.text { render 'reply.text.plain' }
        part.html { render 'reply.text.html' }
      end.deliver!
    ensure
      remove_email_config
    end
  end
  
  def forward(ticket, note, options={})
    check_spam_email(ticket, note)
    email_config = (note.account.email_configs.find_by_reply_email(extract_email(note.from_email)) || ticket.reply_email_config)
    begin
      remove_email_config
      configure_email_config email_config
      to_emails = validate_emails(note.to_emails - [note.account.kbase_email], note)
      from_email = validate_emails(note.from_email, note)
      return if from_email.empty? || to_emails.empty?
      bcc_emails = validate_emails(note.bcc_emails, note)
      cc_emails = validate_emails(note.cc_emails, note)

      message_id = "#{Mail.random_tag}.#{::Socket.gethostname}@forward.freshdesk.com"
      
      headers = email_headers(ticket, message_id, false, false, true).merge({
        :subject    =>  fwd_formatted_subject(ticket),
        :to         =>  to_emails,
        :cc         =>  cc_emails,
        :bcc        =>  bcc_emails,
        :from       =>  from_email,
        "Reply-To"  =>  "#{from_email}"
      })

      set_others_redis_key(message_key(ticket.account_id, message_id),
                         "#{ticket.display_id}:#{message_id}",
                         86400*7) unless message_id.nil?

      headers.merge!(make_header(ticket.display_id, note.id, ticket.account_id, "Forward"))
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      inline_attachments = []
      @ticket = ticket
      @body = note.full_text
      @cloud_files= note.cloud_files
      @body_html = generate_body_html(note.full_text_html)
      @account = note.account
      @attachment_files = note.all_attachments

      if attachments.present? && attachments.inline.present?
        handle_inline_attachments(attachments, note.full_text_html, note.account)
      end

      unless @account.secure_attachments_enabled?
        self.class.trace_execution_scoped(['Custom/Helpdesk::TicketNotifier/read_binary_attachment']) do
          add_attachments
        end
      end

      mail(headers) do |part|
        part.text { render 'forward.text.plain' }
        part.html { render 'forward.text.html' }
      end.deliver!
    ensure
      remove_email_config
    end
  end

  def reply_to_forward(ticket, note, options={})
    check_spam_email(ticket, note)
    email_config = (note.account.email_configs.find_by_id(note.email_config_id) || ticket.reply_email_config)
    begin
      configure_email_config email_config

      to_emails = validate_emails(note.to_emails, note)
      from_email = validate_emails(note.from_email, note)
      return if from_email.empty? || to_emails.empty?
      bcc_emails = validate_emails(note.bcc_emails, note)
      cc_emails = validate_emails(note.cc_emails, note)

      message_id = "#{Mail.random_tag}.#{::Socket.gethostname}@forward.freshdesk.com"
      
      headers = email_headers(ticket, message_id, false).merge({
        :subject    =>  fwd_formatted_subject(ticket),
        :to         =>  to_emails,
        :cc         =>  cc_emails,
        :bcc        =>  bcc_emails,
        :from       =>  from_email,
        "Reply-To"  =>  "#{from_email}"
      })

      headers.merge!(make_header(ticket.display_id, note.id, ticket.account_id, "Reply to Forward"))
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      inline_attachments = []
      @ticket = ticket
      @body = note.full_text
      @cloud_files= note.cloud_files
      @body_html = generate_body_html(note.full_text_html)
      @account = note.account
      @attachment_files = note.all_attachments

      if attachments.present? && attachments.inline.present?
        handle_inline_attachments(attachments, note.full_text_html, note.account)
      end

      unless @account.secure_attachments_enabled?
        self.class.trace_execution_scoped(['Custom/Helpdesk::TicketNotifier/read_binary_attachment']) do
          add_attachments
        end
      end

      mail(headers) do |part|
        part.text { render 'reply_to_forward.text.plain' }
        part.html { render 'reply_to_forward.text.html' }
      end.deliver!
    ensure
      remove_email_config
    end
  end
  
  def email_to_requester(ticket, content, sub=nil)
    email_config = ticket.friendly_reply_email_config
    begin
      configure_email_config email_config
      header_message_id = construct_email_header_message_id(:automation)
      headers   = email_headers(ticket, header_message_id).merge({
        :subject    =>  (sub.blank? ? formatted_subject(ticket) : sub),
        :to         =>  ticket.from_email,
        :from       =>  ticket.friendly_reply_email,
        :sent_on    =>  Time.now,
        "Reply-To"  =>  "#{ticket.friendly_reply_email}"
      })

      headers.merge!(make_header(ticket.display_id, nil, ticket.account_id, "Email to Requestor"))
      headers.merge!({"X-FD-Email-Category" => ticket.friendly_reply_email_config.category}) if ticket.friendly_reply_email_config.category.present?
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
    ensure
        remove_email_config
    end
  end
  
  def internal_email(ticket, receips, content, sub=nil)
    email_config = ticket.friendly_reply_email_config
    begin
      configure_email_config email_config
      header_message_id = construct_email_header_message_id(:automation)
      headers = email_headers(ticket, header_message_id).merge({
        :subject    =>  (sub.blank? ? formatted_subject(ticket) : sub),
        :to         =>  receips,
        :from       =>  ticket.friendly_reply_email,
        :sent_on    =>  Time.now,
        "Reply-To"  =>  "#{ticket.friendly_reply_email}"
      })

      headers.merge!(make_header(ticket.display_id, nil, ticket.account_id, "Internal Email"))
      headers.merge!({"X-FD-Email-Category" => ticket.friendly_reply_email_config.category}) if ticket.friendly_reply_email_config.category.present?
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
    ensure
      remove_email_config
    end
  end

  def notify_outbound_email(ticket)
    check_outbound_count(ticket)
    check_spam_email(ticket)
    begin
      configure_email_config ticket.reply_email_config

      from_email = if ticket.account.personalized_email_replies_enabled? && ticket.responder.present?
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

      headers.merge!(make_header(ticket.display_id, nil, ticket.account_id, "Notify Outbound Email"))
      headers.merge!({"X-FD-Email-Category" => ticket.reply_email_config.category}) if ticket.reply_email_config.category.present?
      inline_attachments   = []
      @account = ticket.account
      @ticket = ticket
      @cloud_files= ticket.cloud_files
      @attachment_files = ticket.all_attachments
      
      if attachments.present? && attachments.inline.present?
        handle_inline_attachments(attachments, ticket.description_html, ticket.account)
      end

      unless @account.secure_attachments_enabled?
        self.class.trace_execution_scoped(['Custom/Helpdesk::TicketNotifier/read_binary_attachment']) do
          add_attachments
        end
      end

      mail(headers) do |part|
        part.text { render 'notify_outbound_email.text.plain' }
        part.html { render 'notify_outbound_email.text.html' }
      end.deliver!
    ensure
      remove_email_config
    end

    set_others_redis_key(message_key(ticket.account_id, message_id),
                         "#{ticket.display_id}:#{message_id}",
                         86400*7) unless message_id.nil?
    update_ticket_header_info(ticket.id, message_id)
  end

  def notify_bulk_child_creation options = {}
    headers = {
      :subject                    => I18n.t("ticket.parent_child.notn_subject"),
      :to                         => options[:user].email,
      :from                       => options[:user].account.default_friendly_email,
      :bcc                        => AppConfig['reports_email'],
      :sent_on                    => Time.now,
      :"Reply-to"                 => "#{options[:user].account.default_friendly_email}",
      :"Auto-Submitted"           => "auto-generated",
      :"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    @user_name         = options[:user].name
    @assoc_parent      = options[:parent_tkt]
    @error_msg         = options[:error_msg]
    @failed_items      = options[:failed_items]
    @total_child_count = options[:child_count]

    mail(headers) do |part|
      part.text { render "notify_bulk_child_creation.text.plain" }
      part.html { render "notify_bulk_child_creation.text.html" }
    end.deliver
  end

  def self.fetch_email_notification(ticket, notification_type)
    return ticket.account.bot_email_response if notification_type == EmailNotification::BOT_RESPONSE_TEMPLATE
    ticket.account.email_notifications.find_by_notification_type(notification_type)
  end

  def self.construct_template_params(ticket, comment, opts = {})
    {
      'ticket' => ticket.to_liquid, 
      'helpdesk_name' => ticket.account.helpdesk_name, 
      'comment' => comment, 
      'freddy_suggestions' => opts[:freddy_suggestions]
    }
  end

  private
    def add_attachments
      @attachment_files.each do |a|
        attachments[a.content_file_name] = {
          encoding: 'base64',
          content: Mail::Encodings::Base64.encode(Paperclip.io_adapters.for(a.content).read),
          mime_type: a.content_content_type
        }
      end
    end

    def construct_email_header_message_id(email_type)
      "#{Mail.random_tag}.#{::Socket.gethostname}@#{Helpdesk::EMAIL_TYPE_TO_MESSAGE_ID_DOMAIN[email_type]}"
    end

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
          ticket.skip_sbrr = ticket.skip_ocr_sync = true
          ticket.save
        end
      end
    end

    def email_headers(ticket, message_id, auto_submitted=true, suppress_references=false, generate_reference = false)
      #default message id
      message_id = message_id || "#{Mail.random_tag}.#{::Socket.gethostname}@email.freshdesk.com"

      headers = {
        "Message-ID"  =>  "<#{message_id}>",
        :sent_on => Time.now.getlocal,
        'X-SOURCE' => EmailNotificationConstants::TICKET_SOURCE[ticket.source - 1]
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
        references, reply_to = build_references(ticket, generate_reference)
        headers["References"] = references unless references.blank?
        headers["In-Reply-To"] = reply_to unless reply_to.blank?
      end

      headers
    end


    def check_spam_email(ticket, note = nil)
      account = ticket.account
      if ((ticket.account_id > get_spam_account_id_threshold) &&
          (account.subscription.state.downcase == "trial") && 
          (Freemail.free_or_disposable?(account.admin_email)) &&
          (ticket.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email] || ticket.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:phone] ))
        if note.present?
          to_emails = validate_emails(note.to_emails, note)
          bcc_emails = validate_emails(note.bcc_emails, note)
          cc_emails = validate_emails(note.cc_emails, note)
          to_emails_count =  to_emails.present? ? to_emails.count : 0
          bcc_emails_count =  bcc_emails.present? ? bcc_emails.count : 0
          cc_emails_count =  cc_emails.present? ? cc_emails.count : 0
          emails_count = to_emails_count + bcc_emails_count + cc_emails_count
          if outgoing_email_limit_reached?(emails_count, ticket.account_id)
            notify_spam_threshold_crossed(account)
          end
        else
          emails_count = ticket.cc_email[:cc_emails].count
          if outgoing_email_limit_reached?(emails_count, ticket.account_id)
            notify_spam_threshold_crossed(account)
          end
        end
      end
    end

    def outgoing_email_limit_reached?(no_of_outgoing, account_id)
      outgoing_count_key = OUTGOING_COUNT_PER_HALF_HOUR % {:account_id => account_id }
      total_outgoing = get_others_redis_key(outgoing_count_key).to_i
      if Thread.current[:attempts].nil? || Thread.current[:attempts] == 0 
        total_outgoing = total_outgoing + no_of_outgoing
      end
      set_others_redis_key(outgoing_count_key,total_outgoing,30.minutes.seconds)
      mail_outgoing_threshold = get_others_redis_key(SPAM_OUTGOING_EMAILS_THRESHOLD) || 30
      mail_outgoing_threshold = mail_outgoing_threshold.to_i 
      if total_outgoing > mail_outgoing_threshold
        return true
      else
        return false
      end
    end

    def notify_spam_threshold_crossed(account)
       FreshdeskErrorsMailer.error_email(nil, {:domain_name => account.full_domain}, nil, {
                  :subject => "Outgoing Spam Threshold Crossed for Acc ID:#{account.id} ", 
                  :recipients => ["mail-alerts@freshdesk.com", "noc@freshdesk.com","helpdesk@noc-alerts.freshservice.com"],
                  :additional_info => {:info => "Account ID: #{account.id} has sent more outgoing emails . Check for spam in this account "}
                  })
    end

    def check_outbound_count(ticket)
      account = ticket.account
      outbound_per_day_key = OUTBOUND_EMAIL_COUNT_PER_DAY % {:account_id => account.id }
      total_outbound_per_day = get_others_redis_key(outbound_per_day_key).to_i
      if total_outbound_per_day == 0
        set_others_redis_key(outbound_per_day_key,total_outbound_per_day,1.days.seconds)
        increment_others_redis(outbound_per_day_key)
      else
        increment_others_redis(outbound_per_day_key)
      end
    end

    def message_key(account_id, message_id)
      EMAIL_TICKET_ID % {:account_id => account_id, :message_id => message_id}
    end

    def build_references(ticket, generate_reference = false)
      if generate_reference and !ticket.header_info_present?
        ticket_message_id = "#{Mail.random_tag}.#{::Socket.gethostname}@email.freshdesk.com"
        set_others_redis_key(message_key(ticket.account_id, ticket_message_id),
                         "#{ticket.display_id}:#{ticket_message_id}",
                         86400*7) unless ticket_message_id.nil?
        update_ticket_header_info(ticket.id, ticket_message_id)
        ticket.reload
      end
      references = generate_email_references(ticket)
      reply_to = in_reply_to(ticket)
      return references, reply_to
    end

    def regular_attachments
      @account.secure_attachments_enabled? ? [] : @attachment_files 
    end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias 
end
