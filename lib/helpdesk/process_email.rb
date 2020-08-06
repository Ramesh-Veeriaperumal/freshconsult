# encoding: utf-8
require 'charlock_holmes'
class Helpdesk::ProcessEmail < Struct.new(:params)
 
  include EmailCommands
  include ParserUtil
  include AccountConstants
  include EmailHelper
  include Helpdesk::ProcessByMessageId
  include Helpdesk::Email::Constants 
  include Helpdesk::DetectDuplicateEmail
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::UrlHelper
  include WhiteListHelper
  include Helpdesk::Utils::Attachment
  include Helpdesk::Utils::ManageCcEmails
  include Helpdesk::Permission::Ticket
  include Helpdesk::ProcessAgentForwardedEmail
  include Cache::Memcache::AccountWebhookKeyCache
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Helpdesk::LanguageDetection
  include ::Email::AntiSpoof
  include ::Email::PerformUtil

  class UserCreationError < StandardError
  end

  class ShardMappingError < StandardError
  end

  MESSAGE_LIMIT = 10.megabytes
  MAXIMUM_CONTENT_LIMIT = 300.kilobytes
  VIRUS_CHECK_ENABLED = false
  LARGE_TEXT_TIMEOUT = 60

  attr_accessor :reply_to_email, :additional_emails,:archived_ticket, :start_time, :actual_archive_ticket

  def email_spam_watcher_counter(account)
    spam_watcher_options = {
          :key => "sw_solution_articles", 
          :threshold => 50,
          :sec_expire => 7200,
    }
    key  = spam_watcher_options[:key]
    threshold = spam_watcher_options[:threshold]
    sec_expire = spam_watcher_options[:sec_expire]
    begin
      Timeout::timeout(SpamConstants::SPAM_TIMEOUT) {
        user_id = ""
        account_id = account.id
        max_count = "#{threshold}".to_i
        final_key = key + ":" + account_id.to_s + ":" + user_id.to_s
        # this case is added for the sake of skipping imports
        return true if ((Time.now.to_i - account.created_at.to_i) > 1.day)
        return true if $spam_watcher.perform_redis_op("get", account_id.to_s + "-" + user_id.to_s)
        count = $spam_watcher.perform_redis_op("rpush", final_key, Time.now.to_i)
        sec_expire = "#{sec_expire}".to_i 
        $spam_watcher.perform_redis_op("expire", final_key, sec_expire+1.minute)
        puts "here"
        if count >= max_count
          puts "inside here"
          head = $spam_watcher.perform_redis_op("lpop", final_key).to_i
          time_diff = Time.now.to_i - head
          puts "*"*100
          puts "#{time_diff}"
          puts "#{sec_expire}"
          puts "*"*100
          if time_diff <= sec_expire
            # ban_expiry = sec_expire - time_diff
            puts "outside here"
            $spam_watcher.perform_redis_op("rpush", SpamConstants::SPAM_WATCHER_BAN_KEY,final_key)
          end
        end
      }
    rescue Exception => e
      puts e
      Rails.logger.error e.backtrace
      NewRelic::Agent.notice_error(e,{:description => "error occured in updating spam_watcher_counter"})
    end
  end


  def perform(parsed_to_email = Hash.new, skip_encoding = false)
    if collab_email_reply? params[:subject]
      # block all email related to collab based on subject
      return processed_email_data(PROCESSED_EMAIL_STATUS[:noop_collab_email_reply])
    end
    # from_email = parse_from_email
    result = {}
    encode_stuffs unless skip_encoding
    email_processing_log("Email received: Message-Id #{message_id}")
    self.start_time = Time.now.utc
    to_email = parsed_to_email.present? ? parsed_to_email : parse_to_email
    shardmapping = ShardMapping.fetch_by_domain(to_email[:domain])
    unless shardmapping.present?
      email_processing_log("Email Processing Failed: No Shard Mapping found!")
      return processed_email_data(PROCESSED_EMAIL_STATUS[:shard_mapping_failed])
    end
    unless shardmapping.ok?
      if shardmapping.status == MAINTENANCE_STATUS
        email_processing_log("Email Processing Failed: Account in maintenance")
        raise ShardMappingError("Account in maintenance")
      else
        email_processing_log("Email Processing Failed: invalid shard mapping status")
        return processed_email_data(PROCESSED_EMAIL_STATUS[:inactive_account])
      end
    end
    Sharding.select_shard_of(to_email[:domain]) do
      account = Account.find_by_full_domain(to_email[:domain])
      if account && account.allow_incoming_emails?
        # clip_large_html
        account.make_current
        email_spam_watcher_counter(account)
        email_processing_log("Processing email request for request_url: #{params[:request_url].to_s}",to_email[:email])
        verify
        TimeZone.set_time_zone
        from_email = parse_from_email(account)
        if from_email.nil?
          email_processing_log("Email Processing Failed: No From Email found!", to_email[:email])
          return processed_email_data(PROCESSED_EMAIL_STATUS[:invalid_from_email], account.id)
        end
        if account.features?(:domain_restricted_access)
          domain = (/@(.+)/).match(from_email[:email]).to_a[1]
          wl_domain  = account.account_additional_settings_from_cache.additional_settings[:whitelisted_domain]
          unless Array.wrap(wl_domain).include?(domain)
            email_processing_log "Email Processing Failed: Not a White listed Domain!", to_email[:email]
            return processed_email_data(PROCESSED_EMAIL_STATUS[:restricted_domain_access], account.id)
          end
        end
        kbase_email = account.kbase_email
      
        if (to_email[:email] != kbase_email) || (get_envelope_to.size > 1)
          email_config = account.email_configs.find_by_to_email(to_email[:email])
          if email_config && (!params[:migration_enable_outgoing]) && (from_email[:email].to_s.downcase == email_config.reply_email.to_s.downcase)
            email_processing_log "Email Processing Failed: From-email and reply-email are same!", to_email[:email]
            return processed_email_data(PROCESSED_EMAIL_STATUS[:self_email], account.id)
          end
          if duplicate_email?(from_email[:email], to_email[:email], params[:subject], message_id)
            return processed_email_data(PROCESSED_EMAIL_STATUS[:duplicate], account.id)
          end

          if (from_email[:email] =~ EMAIL_VALIDATOR).nil?
            envelope_from_email = parse_email JSON.parse(params[:envelope])["from"]
            if (envelope_from_email[:email] =~ EMAIL_VALIDATOR).nil?
              error_msg = "Invalid email address found in requester details - #{from_email[:email]} for account - #{account.id}"
              Rails.logger.debug error_msg
              return processed_email_data(PROCESSED_EMAIL_STATUS[:invalid_from_email], account.id)
            else
              from_email = envelope_from_email
            end
          end
          # check for wildcards
          wc_check_result = check_for_wildcard(email_config, account, to_email)
          return wc_check_result[:message] if wc_check_result[:status]

          user = existing_user(account, from_email)

          unless user
            text_part
            user = create_new_user(account, from_email, email_config)
          else
            if user.blocked?
              email_processing_log "Email Processing Failed: User is been blocked!", to_email[:email]
              return processed_email_data(PROCESSED_EMAIL_STATUS[:user_blocked], account.id)
            end
            text_part
          end
          if (user.blank? && (account.sane_restricted_helpdesk_enabled? || !account.restricted_helpdesk?))
            email_processing_log "Email Processing Failed: Blank User!", to_email[:email]
            return processed_email_data(PROCESSED_EMAIL_STATUS[:blank_user], account.id)
          end
          set_current_user(user)        

          self.class.trace_execution_scoped(['Custom/Helpdesk::ProcessEmail/sanitize']) do
          # Workaround for params[:html] containing empty tags
          #need to format this code --Suman
          if params[:html].blank? && !params[:text].blank? 
            email_cmds_regex = get_email_cmd_regex(account) 
            params[:html] = body_html_with_formatting(params[:text],email_cmds_regex) 
          end
        end
        result = add_to_or_create_ticket(account, from_email, to_email, user, email_config)
      end

      begin
        if kbase_email_present?(kbase_email)
          result = create_article(account, from_email, to_email)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
        Account.reset_current_account
      else
        email_processing_log "Email Processing Failed: No active Account found!"
        Rails.logger.info "Email Processing Failed: No active Account found!"
        if account.nil?
          Rails.logger.info "Email Processing Failed: Account is nil"
          return processed_email_data(PROCESSED_EMAIL_STATUS[:invalid_account])
        elsif !account.active?
          Rails.logger.info "Email Processing Failed: Account is not active"
          return processed_email_data(PROCESSED_EMAIL_STATUS[:inactive_account], account.id)
        else
          Rails.logger.info "Email Processing Failed: Invalid Account"
          return processed_email_data(PROCESSED_EMAIL_STATUS[:invalid_account])
        end   
      end
    end
    elapsed_time = (Time.now.utc - start_time).round(3)
    Rails.logger.info "Time taken for process_email perform : #{elapsed_time} seconds"
    result
  end

  # ITIL Related Methods starts here

  def add_to_or_create_ticket(account, from_email, to_email, user, email_config)
    ticket = nil
    archive_ticket = nil
    unless account.launched?(:skip_ticket_threading)
      ticket, archive_ticket = process_email_ticket_info(account, from_email, user, email_config) 
    end
    if (ticket.present? || archive_ticket.present?) && user.blank?
      if archive_ticket
        parent_ticket = archive_ticket.parent_ticket
        if parent_ticket.is_a?(Helpdesk::Ticket) && can_be_added_to_ticket?(parent_ticket, user, from_email)
          valid_parent_ticket = true
        end
        linked_ticket = archive_ticket.ticket
        if linked_ticket && can_be_added_to_ticket?(linked_ticket.parent, user, from_email)
          valid_linked_ticket = true
          linked_ticket = linked_ticket.parent
        end
      end
      if ticket || valid_parent_ticket || valid_linked_ticket
        user = create_new_user(account, from_email, email_config, true)
        set_current_user(user)
      end
    end
    if user.blank?
      email_processing_log "Email Processing Failed: Blank User!", to_email[:email]
      return processed_email_data(PROCESSED_EMAIL_STATUS[:blank_user], account.id)
    end
    params[:cc] = permissible_ccs(user, params[:cc], account)
    if ticket
      if(from_email[:email].to_s.downcase == ticket.reply_email.to_s.downcase) #Premature handling for email looping..
        email_processing_log "Email Processing Failed: Email cannot be threaded. From-email and Ticket's reply-email email are same!", to_email[:email]
        return processed_email_data(PROCESSED_EMAIL_STATUS[:self_email], account.id)
      end
      primary_ticket = check_primary(ticket,account)
      if primary_ticket 
        return create_ticket(account, from_email, to_email, user, email_config) if primary_ticket.is_a?(Helpdesk::ArchiveTicket)
        ticket = primary_ticket
      end
      return add_email_to_ticket(ticket, from_email, to_email, user)
    else
      if archive_ticket
        self.archived_ticket = archive_ticket
        # If merge ticket change the archive_ticket
        if parent_ticket && parent_ticket.is_a?(Helpdesk::ArchiveTicket)
          self.archived_ticket = parent_ticket
        elsif valid_parent_ticket
          return add_email_to_ticket(parent_ticket, from_email, to_email, user)
        end
        # If not merge check if archive child present
        if valid_linked_ticket
          return add_email_to_ticket(linked_ticket, from_email, to_email, user)
        end
      end
      return create_ticket(account, from_email, to_email, user, email_config)
    end
  end

  def encoded_display_id_regex account
    Regexp.new("\\[#{account.ticket_id_delimiter}([0-9]*)\\]")
  end

  # ITIL Related Methods ends here

  def create_article(account, from_email, to_email)

    article_params = {}

    email_config = account.email_configs.find_by_to_email(to_email[:email])
    user = get_user(account, from_email,email_config)
    
    article_params[:title] = params[:subject].gsub( encoded_display_id_regex(account), "" )
    article_params[:description] = cleansed_html || simple_format(params[:text])
    article_params[:user] = user.id
    article_params[:account] = account.id
    article_params[:content_ids] = params["content-ids"].nil? ? {} : get_content_ids

    article_params[:attachment_info] = JSON.parse(params["attachment-info"]) if params["attachment-info"]
    attachments = {}
    
    Integer(params[:attachments]).times do |i|
      attachments["attachment#{i+1}"] = params["attachment#{i+1}"]
    end
      
    article_params[:attachments] = attachments
    
    article = Helpdesk::KbaseArticles.create_article_from_email(article_params)
    if article.present?
      return processed_email_data(PROCESSED_EMAIL_STATUS[:success], account.id, article) 
    else
      return processed_email_data(PROCESSED_EMAIL_STATUS[:failed_article], account.id)
    end
  end

  private

    def encode_stuffs
      charsets = params[:charsets].blank? ? {} : ActiveSupport::JSON.decode(params[:charsets])
      [ :html, :text, :subject, :headers, :from ].each do |t_format|
        unless params[t_format].nil?
          charset_encoding = (charsets[t_format.to_s] || "UTF-8").strip()
          # if !charset_encoding.nil? and !(["utf-8","utf8"].include?(charset_encoding.downcase))
          if ((t_format == :subject || t_format == :headers) && (charsets[t_format.to_s].blank? || charsets[t_format.to_s].upcase == "UTF-8") && (!params[t_format].valid_encoding?))
            begin
              params[t_format] = params[t_format].encode(Encoding::UTF_8, :undef => :replace, 
                                                                      :invalid => :replace, 
                                                                      :replace => '')
              next
            rescue Exception => e
              Rails.logger.error "Error While encoding in process email  \n#{e.message}\n#{e.backtrace.join("\n\t")} #{params}"
            end
          end
          replacement_char = "\uFFFD"
          if t_format.to_s == "subject" and (params[t_format] =~ /=\?(.+)\?[BQ]?(.+)\?=/ or params[t_format].include? replacement_char)
            params[t_format] = decode_subject
          else
            begin
              params[t_format] = Iconv.new('utf-8//IGNORE', charset_encoding).iconv(params[t_format])
            rescue Exception => e
              mapping_encoding = {
                "ks_c_5601-1987" => "CP949",
                "unicode-1-1-utf-7"=>"UTF-7",
                "_iso-2022-jp$esc" => "ISO-2022-JP",
                "charset=us-ascii" => "us-ascii",
                "iso-8859-8-i" => "iso-8859-8",
                "unicode" => "utf-8",
                "cp-850" => "CP850"
              }
              if mapping_encoding[charset_encoding.downcase]
                params[t_format] = Iconv.new('utf-8//IGNORE', mapping_encoding[charset_encoding.downcase]).iconv(params[t_format])
              elsif ((charsets[t_format.to_s].blank? || charsets[t_format.to_s].upcase == "UTF-8") && (!params[t_format].valid_encoding?))
                  replace_invalid_characters t_format
              else
                Rails.logger.error "Error While encoding in process email  \n#{e.message}\n#{e.backtrace.join("\n\t")} #{params}"
                NewRelic::Agent.notice_error(e,{:description => "Charset Encoding issue with ===============> #{charset_encoding}"})
              end
            end
          end
        end
      end
    end

    def decode_subject
      subject = params[:subject]
      replacement_char = "\uFFFD"
      if subject.include? replacement_char
        params[:headers] =~ /^subject\s*:(.+)$/i
        subject = $1.strip
        unless subject =~ /=\?(.+)\?[BQ]?(.+)\?=/
          detected_encoding = CharlockHolmes::EncodingDetector.detect(subject)
          detected_encoding = {:encoding => "UTF-8"} if detected_encoding.nil?
          begin
            decoded_subject = subject.force_encoding(detected_encoding[:encoding]).encode(Encoding::UTF_8, :undef => :replace, 
                                                                              :invalid => :replace, 
                                                                              :replace => '')
          rescue Exception => e
            decoded_subject = subject.force_encoding("UTF-8").encode(Encoding::UTF_8, :undef => :replace, 
                                                                      :invalid => :replace, 
                                                                      :replace => '')
          end
          subject = decoded_subject if decoded_subject
        end
      end
      if subject =~ /=\?(.+)\?[BQ]?(.+)\?=/
        decoded_subject = ""
        subject_arr = subject.split("?=")
        subject_arr.each do |sub|
          decoded_string = Mail::Encodings.unquote_and_convert_to("#{sub}?=", 'UTF-8')
          decoded_subject << decoded_string
        end
        subject = decoded_subject.strip
      end
      subject
    end

    def parse_email(email_text)
      parsed_email = parse_email_text(email_text)
      
      name = parsed_email[:name]
      email = parsed_email[:email]

      if(email && (email =~ EMAIL_REGEX))
        email = $1
      elsif(email_text =~ EMAIL_REGEX) 
        email = $1  
      end

      name ||= ""
      domain = (/@(.+)/).match(email).to_a[1]
      
      {:name => name, :email => email, :domain => domain}
    end

    def parse_reply_to_email
      if(!params[:headers].nil? && params[:headers] =~ /^reply-to:(.+)$/i)
        self.additional_emails = get_email_array($1.strip)[1..-1]
        parsed_reply_to = parse_email($1.strip)
        self.reply_to_email = parsed_reply_to if parsed_reply_to[:email] =~ EMAIL_REGEX
      end
      reply_to_email
    end

    def orig_email_from_text #To process mails fwd'ed from agents
      @orig_email_user ||= begin
        content = text_part
        identify_original_requestor(content)
      end
    end

    def parse_to_email
      envelope = params[:envelope]
      unless envelope.nil?
        envelope_to = (ActiveSupport::JSON.decode envelope)['to']
        return parse_email envelope_to.first unless (envelope_to.nil? || envelope_to.empty?)
      end
      
      parse_email params[:to]
    end

    def kbase_email_present? kbase_email
      return false if auto_generated?(params[:headers])
      envelope = params[:envelope]
      return false if envelope.blank?
      envelope_to = (ActiveSupport::JSON.decode envelope)['to']
      return false if envelope_to.blank?
      envelope_to.map {|to_email| parse_email(to_email)[:email]}.include?(kbase_email) 
    end
    
    def parse_from_email account
      reply_to_feature = account.features?(:reply_to_based_tickets)
      parse_reply_to_email if reply_to_feature

      #Assigns email of reply_to if feature is present or gets it from params[:from]
      #Will fail if there is spaces and no key after reply_to or has a garbage string
      f_email = reply_to_email || parse_email(params[:from].strip)
      
      #Ticket will be created for no_reply if there is no other reply_to
      f_email = reply_to_email if valid_from_email?(f_email, reply_to_feature)
      return f_email unless f_email[:email].blank?
    end

    def valid_from_email? f_email, reply_to_feature
      (f_email[:email] =~ /(noreply)|(no-reply)/i or f_email[:email].blank?) and !reply_to_feature and parse_reply_to_email
    end

    def parse_cc_email
      cc_array = []
      unless params[:cc].nil?
        cc_array = params[:cc].split(',').collect! {|n| (parse_email n)[:email]}
      end
      cc_array.concat(additional_emails || [])
      return cc_array.compact.map{|i| i.downcase}.uniq
    end

    def parse_cc_email_new
      cc_array = get_email_array params[:cc]
      cc_array.concat(additional_emails || [])
      cc_array.compact.map{|i| i.downcase}.uniq
    end

    def parse_to_emails
      to_emails = params[:to].split(",") if params[:to]
      parsed_to_emails = []
      (to_emails || []).each do |email|
        parsed_email = parse_email_text(email)
        parsed_to_emails.push("#{parsed_email[:name]} <#{parsed_email[:email].strip}>") if !parsed_email.blank? && !parsed_email[:email].blank?
      end
      parsed_to_emails
    end

    def parse_to_emails_new
      fetch_valid_emails params[:to]
    end

    def fetch_ticket(account, from_email, user, email_config)
      display_id = Helpdesk::Ticket.extract_id_token(params[:subject], account.ticket_id_delimiter)
      ticket = account.tickets.find_by_display_id(display_id) if display_id
      if can_be_added_to_ticket?(ticket, user, from_email)
        Rails.logger.info "Found existing ticket by display id present in subject"
        return ticket 
      end
      ticket = ticket_from_headers(from_email, account, email_config, user)
      if ticket.present?
        Rails.logger.info "Found existing ticket by references(reference, in-reply-to) present in header"
        return ticket 
      end
      ticket = ticket_from_email_body(account)
      if can_be_added_to_ticket?(ticket, user, from_email)
        Rails.logger.info "Found existing ticket by fd_tkt_identifier present in HTML content"
        return ticket 
      end
      ticket = ticket_from_id_span(account)
      if can_be_added_to_ticket?(ticket, user, from_email)
        Rails.logger.info "Found existing ticket by fdtktid present in HTML content"
        return ticket 
      end
    end

    def fetch_archived_ticket(account, from_email, user, email_config)
      display_id = Helpdesk::Ticket.extract_id_token(params[:subject], account.ticket_id_delimiter)
      archive_ticket = account.archive_tickets.find_by_display_id(display_id) if display_id
      return archive_ticket if can_be_added_to_ticket?(archive_ticket, user, from_email)
      archive_ticket = archive_ticket_from_headers(from_email, account, email_config, user)
      return archive_ticket if can_be_added_to_ticket?(archive_ticket, user, from_email)
      return self.actual_archive_ticket if can_be_added_to_ticket?(self.actual_archive_ticket, user, from_email)
    end
    
    def create_ticket(account, from_email, to_email, user, email_config)
      e_email = {}
      if (user.agent? && !user.deleted?)
        e_email = (account.features_included?(:disable_agent_forward) ? {} : orig_email_from_text) unless composed_email?
        if e_email[:cc_emails].present?
          params[:cc] = (params[:cc].present?) ? (params[:cc] << ", " << e_email[:cc_emails].join(", ")) : e_email[:cc_emails]
        end
        user = get_user(account, e_email , email_config, true) unless e_email.blank?
      end
      to_emails = parse_to_emails
      global_cc = parse_all_cc_emails(account.kbase_email, account.support_emails)
      if max_email_limit_reached? "Ticket", to_emails, global_cc 
        email_processing_log "You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for the ticket"
        return processed_email_data(PROCESSED_EMAIL_STATUS[:max_email_limit], account.id)
      end
      ticket_params = build_ticket_params account, user, to_email, global_cc, email_config
      ticket = Helpdesk::Ticket.new(ticket_params)
      ticket.sender_email = e_email[:email] || from_email[:email]
      ticket = check_for_chat_scources(ticket,from_email)
      ticket = check_for_spam(ticket)
      ticket.update_email_received_at(params[:x_received_at] || parse_internal_date(params[:internal_date]))
      check_for_auto_responders(ticket)
      check_support_emails_from(account, ticket, user, from_email)

      begin
        if (ticket.agent_performed?(user) && !user.deleted?)
          process_email_commands(ticket, user, email_config, params) if user.privilege?(:edit_ticket_properties)
          email_cmds_regex = get_email_cmd_regex(account)
          ticket.ticket_body.description = ticket.description.gsub(email_cmds_regex, "") if(!ticket.description.blank? && email_cmds_regex)
          ticket.ticket_body.description_html = ticket.description_html.gsub(email_cmds_regex, "") if(!ticket.description_html.blank? && email_cmds_regex)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      message_key = zendesk_email || message_id
      ticket = update_spam_data(ticket)
      assign_language(user, account, ticket)
      # Creating attachments without attachable info
      # Hitting S3 outside create-ticket transaction
      self.class.trace_execution_scoped(['Custom/Sendgrid/ticket_attachments']) do
        # attachable info will be updated on ticket save
        ticket.attachments, ticket.inline_attachments = create_attachments(ticket, account)
      end

      unless params[:dropped_cc_emails].blank?
        ticket.cc_email[:dropped_cc_emails] = params[:dropped_cc_emails]
      end
      message_id_list = []
      begin
        self.class.trace_execution_scoped(['Custom/Sendgrid/tickets']) do
          message_id_list.push(message_key).push(all_message_ids).flatten!.uniq!
          (ticket.header_info ||= {}).merge!(:message_ids => message_id_list) unless message_id_list.blank?
          if large_email && duplicate_email?(from_email[:email], 
                                                    to_email[:email], 
                                                    params[:subject], 
                                                    message_id)
            return processed_email_data(PROCESSED_EMAIL_STATUS[:duplicate], account.id)
          end
          if account.features_included?(:archive_tickets) && archived_ticket
            ticket.build_archive_child(:archive_ticket_id => archived_ticket.id) 
            # tags = archived_ticket.tags
            # add_ticket_tags(tags,ticket) unless tags.blank?
          end
          if params[:migration_tags]
            tags_hash = JSON.parse(params[:migration_tags])
            add_tags(tags_hash, account, ticket)
          end
          ticket.save_ticket!
          email_processing_log "Email Processing Successful: Email Successfully created as Ticket!!", to_email[:email]
          cleanup_attachments ticket
          mark_email(process_email_key, from_email[:email], 
                                        to_email[:email], 
                                        params[:subject], 
                                        message_id) if large_email
        end

      
        

      rescue Aws::S3::Errors::ServiceError => e # PRE-RAILS4 Changed S3 base error class as InvalidURI is not available in V2
        # FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
        email_processing_log "Email Processing Failed: Couldn't store attachment in S3!", to_email[:email]
        raise e
      rescue ActiveRecord::RecordInvalid => e
        # FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
        NewRelic::Agent.notice_error(e)
      end

      if !(ticket.spam == true && ticket.skip_notification == true)
        message_id_list.each do |msg_key|
          store_ticket_threading_info(account, msg_key, ticket)
        end
      end
      # ticket
      return processed_email_data(PROCESSED_EMAIL_STATUS[:success], account.id, ticket)
    end

    def add_tags tags_hash, account, ticket
      if tags_hash.present?
        tags_hash.each do |tag_name|
          custom_tag = account.tags.find_by_name(tag_name)
          custom_tag = account.tags.create(:name => tag_name) if custom_tag.nil?
          ticket.tags << custom_tag unless (ticket.tags.include? custom_tag)
        end
      end
    end

    def build_ticket_params account, user, to_email, global_cc, email_config
      ticket_params = {
        :account_id => account.id,
        :subject => params[:subject],
        :ticket_body_attributes => {:description => tokenize_emojis(params[:text]) || "",
                          :description_html => cleansed_html || ""},
        :requester => user,
        :to_email => to_email[:email],
        :to_emails => parse_to_emails,
        :cc_email => {:cc_emails => global_cc.dup, :fwd_emails => [],
          :bcc_emails => [], :reply_cc => global_cc.dup, :tkt_cc => parse_cc_email },
        :email_config => email_config,
        :status => Helpdesk::Ticketfields::TicketStatus::OPEN,
        :source => Account.current.helpdesk_sources.ticket_source_keys_by_token[:email]
      }
      ticket_params.merge!({
                  :created_at => params[:migration_internal_date].to_time,
                  :updated_at => params[:migration_internal_date].to_time,
                  :status => params[:migration_status]
                  }) if (params[:migration_internal_date] && params[:migration_status])
      ticket_params
    end

    def store_ticket_threading_info(account, message_id, ticket)
      related_ticket_info = get_ticket_info_from_redis(account, message_id)
      if related_ticket_info
        ticket_id_list = $1 if related_ticket_info =~ /(.+?):/
      end
      related_tickets_display_info = ticket_id_list.present? ? ((ticket_id_list.to_s) +","+ (ticket.display_id.to_s)) : ticket.display_id.to_s

      set_ticket_id_with_message_id account, message_id, related_tickets_display_info
    end
    
    def check_for_spam(ticket)
      ticket.spam = true if ticket.requester.deleted?
      ticket  
    end

    def check_for_chat_scources(ticket,from_email)
      ticket.source = Account.current.helpdesk_sources.ticket_source_keys_by_token[:chat] if Helpdesk::Ticket::CHAT_SOURCES.has_value?(from_email[:domain])
      if from_email[:domain] == Helpdesk::Ticket::CHAT_SOURCES[:snapengage]
        emailreg = Regexp.new(/\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/)
        chat_email =  params[:subject].scan(emailreg).uniq[0]
        ticket.email = chat_email unless chat_email.blank? && (chat_email == "unknown@example.com")
      end
      ticket
    end

    def check_for_auto_responders(model)
      model.skip_notification = true if (params[:migration_skip_notification] || auto_generated?(params[:headers]))
    end
    
    def auto_generated?(headers)
      !headers.blank? && (
        (headers =~ /Auto-Submitted: auto-(.)+/i) || 
        (headers =~ /Precedence: auto_reply/) || 
        (headers =~ /Precedence: (bulk|junk)/i)
      )
    end

    def check_support_emails_from(account, model, user, from_email)
      model.skip_notification = true if user && account.support_emails.any? {|email| email.casecmp(from_email[:email]) == 0}
    end

    #Todo: Check code duplicate available in mailgun controller side - try to merge both & reuse it
    def ticket_from_email_body(account)
      display_span = run_with_timeout(NokogiriTimeoutError) { 
                        Nokogiri::HTML(params[:html]).css("span[title='fd_tkt_identifier']") 
                      }
      unless display_span.blank?
        display_id, fetched_account_id = display_span.last.inner_html.split(":")
        unless display_id.blank?
          return if email_from_another_portal?(account, fetched_account_id)
          ticket = account.tickets.find_by_display_id(display_id.to_i)
          self.actual_archive_ticket = account.archive_tickets.find_by_display_id(display_id.to_i) if account.features_included?(:archive_tickets) && !ticket
          return ticket 
        end 
      end
    end

    #Todo: Check code duplicate available in mailgun controller side - try to merge both & reuse it
    def ticket_from_id_span(account)
      parsed_html = run_with_timeout(NokogiriTimeoutError) { Nokogiri::HTML(params[:html]) }
      display_span = parsed_html.css("span[style]").select{|x| x.to_s.include?('fdtktid')}
      unless display_span.blank?
        display_id, fetched_account_id = display_span.last.inner_html.split(":")
        display_span.last.remove
        params[:html] = parsed_html.inner_html
        unless display_id.blank?
          return if email_from_another_portal?(account, fetched_account_id)
          ticket = account.tickets.find_by_display_id(display_id.to_i)
          self.actual_archive_ticket = account.archive_tickets.find_by_display_id(display_id.to_i) if account.features_included?(:archive_tickets) && !ticket
          return ticket 
        end 
      end
    end

    def archive_ticket_from_email_body(account)
      display_span = Nokogiri::HTML(params[:html]).css("span[title='fd_tkt_identifier']")
      unless display_span.blank?
        display_id = display_span.last.inner_html
        return account.archive_tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
      end
    end

    def archive_ticket_from_id_span(account)
      parsed_html = Nokogiri::HTML(params[:html])
      display_span = parsed_html.css("span[style]").select{|x| x.to_s.include?('fdtktid')}
      unless display_span.blank?
        display_id = display_span.last.inner_html
        display_span.last.remove
        params[:html] = parsed_html.inner_html
        return account.archive_tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
      end
    end


    def add_email_to_ticket(ticket, from_email, to_email, user)
      msg_hash = {}
      # for plain text
      msg_hash = show_quoted_text(params[:text],ticket.reply_email)
      unless msg_hash.blank?
        body = msg_hash[:body]
        full_text = msg_hash[:full_text]
      end
      # for html text
      msg_hash = show_quoted_text(cleansed_html, ticket.reply_email,false)
      unless msg_hash.blank?
        body_html = msg_hash[:body]
        full_text_html = msg_hash[:full_text]
      end
      
      from_fwd_recipients = from_fwd_emails?(ticket, from_email)
      parsed_cc_emails = parse_cc_email
      parsed_cc_emails.delete(ticket.account.kbase_email)
      cc_emails = parsed_cc_emails
      to_emails = parse_to_emails
      if max_email_limit_reached? "Note", to_emails, cc_emails
        email_processing_log "You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for the note"
        return processed_email_data(PROCESSED_EMAIL_STATUS[:max_email_limit], ticket.account.id)
      end
      note_params = build_note_params ticket, from_email, user, from_fwd_recipients, body, body_html, full_text, full_text_html, cc_emails
      note = ticket.notes.build note_params
      note.subject = Helpdesk::HTMLSanitizer.clean(params[:subject])   
      note.source = Account.current.helpdesk_sources.note_source_keys_by_token["note"] if (from_fwd_recipients or ticket.agent_performed?(user) or rsvp_to_fwd?(ticket, from_email, user))
      note.schema_less_note.category = ::Helpdesk::Note::CATEGORIES[:third_party_response] if rsvp_to_fwd?(ticket, from_email, user)
      note.update_email_received_at(params[:x_received_at] || parse_internal_date(params[:internal_date]))

      check_for_auto_responders(note)
      check_support_emails_from(ticket.account, note, user, from_email)

      begin
        ticket.cc_email = ticket_cc_emails_hash(ticket, note)
        if (ticket.agent_performed?(user) && !user.deleted?)
          process_email_commands(ticket, user, ticket.email_config, params, note) if 
            user.privilege?(:edit_ticket_properties)
          email_cmds_regex = get_email_cmd_regex(ticket.account)
          note.note_body.body = body.gsub(email_cmds_regex, "") if(!body.blank? && email_cmds_regex)
          note.note_body.body_html = body_html.gsub(email_cmds_regex, "") if(!body_html.blank? && email_cmds_regex)
          note.note_body.full_text = full_text.gsub(email_cmds_regex, "") if(!full_text.blank? && email_cmds_regex)
          note.note_body.full_text_html = full_text_html.gsub(email_cmds_regex, "") if(!full_text_html.blank? && email_cmds_regex)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end

      # Creating attachments without attachable info
      # Hitting S3 outside create-note transaction
      self.class.trace_execution_scoped(['Custom/Sendgrid/note_attachments']) do
        # attachable info will be updated on note save
        note.attachments, note.inline_attachments = create_attachments(note, ticket.account)
      end

      unless params[:dropped_cc_emails].blank?
        note.cc_emails = {:cc_emails => note.cc_emails, :dropped_cc_emails => params[:dropped_cc_emails]}
      end

      self.class.trace_execution_scoped(['Custom/Sendgrid/notes']) do
        # ticket.save
        note.notable = ticket
        if large_email && duplicate_email?(from_email[:email], 
                                                  parse_to_emails.first, 
                                                  params[:subject], 
                                                  message_id)
          return processed_email_data(PROCESSED_EMAIL_STATUS[:duplicate], ticket.account_id)
        end
        if params[:migration_tags]
          tags_hash = JSON.parse(params[:migration_tags])
          add_tags(tags_hash, ticket.account, ticket)
        end
        note.save_note
        email_processing_log "Email Processing Successful: Email Successfully created as Note!!", to_email[:email]
        cleanup_attachments note
        mark_email(process_email_key, from_email[:email], 
                                      to_email[:email], 
                                      params[:subject], 
                                      message_id) if large_email
      end
      # note
      return processed_email_data(PROCESSED_EMAIL_STATUS[:success], note.account_id, note)
    end

    def build_note_params ticket, from_email, user, from_fwd_recipients, body, body_html, full_text, full_text_html, cc_emails
      hide_response_from_customer = ticket.account.launched?(:hide_response_from_customer_feature) ? customer_removed_in_reply?(ticket, in_reply_to, parse_to_emails, cc_emails, from_email) : false
      note_params = {
        :private => (from_fwd_recipients or reply_to_private_note?(all_message_ids) or rsvp_to_fwd?(ticket, from_email, user) or hide_response_from_customer),
        :incoming => true,
        :note_body_attributes => {
          :body => tokenize_emojis(body) || "",
          :body_html => body_html || "",
          :full_text => tokenize_emojis(full_text),
          :full_text_html => full_text_html || ""
         },
        :source => Account.current.helpdesk_sources.note_source_keys_by_token["email"],
        :user => user, #by Shan temp
        :account_id => ticket.account_id,
        :from_email => from_email[:email],
        :to_emails => parse_to_emails,
        :cc_emails => cc_emails
      }
      note_params.merge!({
              :created_at => params[:migration_internal_date].to_time,
              :updated_at => params[:migration_internal_date].to_time
              }) if params[:migration_internal_date]
      note_params
    end

    def rsvp_to_fwd?(ticket, from_email, user)
      @rsvp_to_fwd ||= ((Account.current.features?(:threading_without_user_check) || (!ticket.cc_email.nil? && !ticket.cc_email[:cc_emails].nil? && ticket.cc_email[:cc_emails].include?(from_email[:email])) || user.agent?) && reply_to_forward(all_message_ids))
    end

    def text_part
      begin
        Timeout.timeout(LARGE_TEXT_TIMEOUT) do
          if(params[:text].nil? || params[:text].empty?) 
            if params[:html].size < MAXIMUM_CONTENT_LIMIT
              params[:text] = Helpdesk::HTMLSanitizer.html_to_plain_text(params[:html])
            else
              email_processing_log "Large Email deducted . Content exceeding maximum content limit #{MAXIMUM_CONTENT_LIMIT} . "
              params[:text] = Helpdesk::HTMLSanitizer.html_to_plain_text(truncate(params[:html], :length => MAXIMUM_CONTENT_LIMIT))
            end
          end
        end
        return params[:text]
      rescue SystemStackError => e
        params[:text] = ""
        return params[:text]
      rescue => e
        Rails.logger.info "Exception while getting text_part , message :#{e.message} - #{e.backtrace}"
      end
      params[:text] = ""
    end
    
    def get_user(account, from_email, email_config, force_create = false)
      user = existing_user(account, from_email)
      unless user.present?
        if force_create || can_create_ticket?(from_email[:email])
          user = create_new_user(account, from_email, email_config, true)
        end
      end
      set_current_user(user)
    end

    def existing_user(account, from_email)
      account.user_emails.user_for_email(from_email[:email])
    end

    def create_new_user(account, from_email, email_config, force_create = false)
      if force_create || can_create_ticket?(from_email[:email])
        user = account.contacts.new
        language = (account.features?(:dynamic_content)) ? nil : account.language
        portal = (email_config && email_config.product) ? email_config.product.portal : account.main_portal
        begin
          signup_status = user.signup!({:user => {:email => from_email[:email], :name => from_email[:name],
            :helpdesk_agent => false, :language => language, :created_from_email => true }, :email_config => email_config},portal)
          raise UserCreationError, "Failed to create new Account!" unless signup_status
        rescue UserCreationError => e
          NewRelic::Agent.notice_error(e)
          Account.reset_current_account
          email_processing_log "Email Processing Failed: Couldn't create new user!"
          raise e
        end
      else
        email_processing_log "Can't create new user for #{from_email.inspect}"
      end
      user
    end

    def max_email_limit_reached? model_name, to_emails, cc_emails
      if model_name == "Note"
        return ((cc_emails.present? && (cc_emails.count >= TicketConstants::MAX_EMAIL_COUNT)) || (to_emails.present? && (to_emails.count >= TicketConstants::MAX_EMAIL_COUNT))) 
      elsif model_name == "Ticket"
        return (cc_emails.present? && (cc_emails.count >= TicketConstants::MAX_EMAIL_COUNT))
      end
    end

    def set_current_user(user)
      user.make_current if user.present?
    end
    
    def create_attachments(item, account)
      attachments = []
      inline_attachments = []
      content_id_hash = {}
      inline_count = 0
      content_ids = params["content-ids"].nil? ? {} : get_content_ids

      Integer(params[:attachments]).times do |i|
        begin
          if params["attachment#{i+1}"].nil?
            Rails.logger.info("Create attachment skipped for attachment#{i+1} Reason : Attachment object is nil")
            next
          end
          content_id = content_ids["attachment#{i+1}"] && 
                        verify_inline_attachments(item, content_ids["attachment#{i+1}"])
          att = Helpdesk::Attachment.create_for_3rd_party(account, item, 
                  params["attachment#{i+1}"], i, content_id, true) unless virus_attachment?(params["attachment#{i+1}"], account)
          if att && (att.is_a? Helpdesk::Attachment)
            if content_id && !att["content_file_name"].include?(".svg")
              content_id_hash[att.content_file_name+"#{inline_count}"] = content_ids["attachment#{i+1}"]
              inline_count+=1
              inline_attachments.push att
            else
              attachments.push att
            end
            att.skip_virus_detection = true
          end
        rescue HelpdeskExceptions::AttachmentLimitException => ex
          Rails.logger.error("ERROR ::: #{ex.message}")
          message = attachment_exceeded_message(ATTACHMENT_LIMIT.megabytes)
          add_notification_text item, message
          break
        rescue Exception => e
          Rails.logger.error("Error while adding item attachments for ::: #{e.message}")
          raise e
        end
      end
      if @total_virus_attachment
        message = virus_attachment_message(@total_virus_attachment)
        add_notification_text item, message
      end
      item.header_info = {:content_ids => content_id_hash} unless content_id_hash.blank?
      return attachments, inline_attachments
    end

    def virus_attachment? attachment, account
      if account.launched?(:antivirus_service)
        begin
          file_attachment = (attachment.is_a? StringIO) ? attachment : File.open(attachment.tempfile)
          result = Email::AntiVirus.scan(io: file_attachment) 
          if result && result[0] == "virus"
            @total_virus_attachment = 0 unless @total_virus_attachment
            @total_virus_attachment += 1  
            return true
          end
        rescue => e
         Rails.logger.info "Error While checking attachment for virus in account #{account.id}, #{e.class}, #{e.message}, #{e.backtrace}"
        end 
      end
      return false
    end

    def add_notification_text item, message
      notification_text = "\n" << message
      notification_text_html = Helpdesk::HTMLSanitizer.clean(content_tag(:div, message, :class => "attach-error"))
      if item.is_a?(Helpdesk::Ticket)
        item.description << notification_text
        item.description_html << notification_text_html
      elsif item.is_a?(Helpdesk::Note)
        item.body << notification_text
        item.body_html << notification_text_html
      end
    end

    def get_content_ids
        content_ids = {}
        split_content_ids = params["content-ids"].tr("{}\\\"","").split(",")
        split_content_ids.each do |content_id|
          split_content_id = content_id.split(":")
          content_ids[split_content_id[1]] = split_content_id[0]
        end
        content_ids
    end

    def show_quoted_text(text, address,plain=true)

      return text if text.blank?

      Timeout.timeout(LARGE_TEXT_TIMEOUT) do
        from_all_regex = "from"     # will be replaced in redis like "(from|von)"
        from_all_regex = $redis_others.get(QUOTED_TEXT_PARSE_FROM_REGEX) || from_all_regex

        regex_arr = [
          Regexp.new("#{from_all_regex}:\s*" + Regexp.escape(address), Regexp::IGNORECASE),
          Regexp.new("<" + Regexp.escape(address) + ">", Regexp::IGNORECASE),
          Regexp.new(Regexp.escape(address) + "\s+wrote:", Regexp::IGNORECASE),
          # Temporary comment out due to process looping for large size emails(gem upgradion ussue)
          # Regexp.new("\\n.*.\d.*." + Regexp.escape(address) ),
          Regexp.new("<div>\n<br>On.*?wrote:"), #iphone
          Regexp.new("On((?!On).)*wrote:"),
          Regexp.new("-+original\s+message-+\s*", Regexp::IGNORECASE),
          Regexp.new("#{from_all_regex}:\s*", Regexp::IGNORECASE)
        ]
        tl = text.length

        #calculates the matching regex closest to top of page
        index = regex_arr.inject(tl) do |min, regex|
            (text.index(regex) or tl) < min ? (text.index(regex) or tl) : min
        end

        original_msg = text[0, index]
        old_msg = text[index,text.size]

        return  {:body => original_msg, :full_text => text } if plain
        #Sanitizing the original msg
        unless original_msg.blank?
          sanitized_org_msg = Nokogiri::HTML(original_msg).at_css("body")
          unless sanitized_org_msg.blank?
            remove_identifier_span(sanitized_org_msg)
            original_msg = sanitized_org_msg.inner_html
          end
        end
        #Sanitizing the old msg
        unless old_msg.blank?
          sanitized_old_msg = Nokogiri::HTML(old_msg).at_css("body")
          unless sanitized_old_msg.blank?
            remove_identifier_span(sanitized_old_msg)
            remove_survey_div(sanitized_old_msg) unless plain
            old_msg = sanitized_old_msg.inner_html
          end
        end

        full_text = original_msg
        unless old_msg.blank?

         full_text = full_text +
         "<div class='freshdesk_quote'>" +
         "<blockquote class='freshdesk_quote'>" + old_msg + "</blockquote>" +
         "</div>"
        end
        return {:body => full_text,:full_text => full_text}  #temp fix made for showing quoted text in incoming conversations
      end
    rescue => e
      Rails.logger.info "Exception in show_quoted_text , message :#{e.message} - #{e.backtrace}"
      return {:body => text,:full_text => text}
    end

    def remove_identifier_span msg
      id_span = msg.css("span[title='fd_tkt_identifier']")
      id_span.remove if id_span
    end

    def get_envelope_to
      envelope = params[:envelope]
      envelope_to = envelope.nil? ? [] : (ActiveSupport::JSON.decode envelope)['to']
      envelope_to
    end

    def from_fwd_emails?(ticket,from_email)
      cc_email_hash_value = ticket.cc_email_hash
      unless cc_email_hash_value.nil?
        cc_email_hash_value[:fwd_emails].any? {|email| email.include?(from_email[:email].downcase) }
      else
        false
      end
    end

    def ticket_cc_emails_hash(ticket, note)
      to_email   = parse_to_email[:email]
      to_emails  = get_email_array(params[:to])
      new_cc_emails = parse_cc_email
      updated_ticket_cc_emails(new_cc_emails, ticket, note, in_reply_to, 
        to_email, to_emails)
    end

    #possible unwanted code. Not used now.
    def clip_large_html
      return unless params[:html]
      @description_html = Helpdesk::HTMLSanitizer.clean(params[:html])
      if @description_html.bytesize > MESSAGE_LIMIT
        Rails.logger.debug "$$$$$$$$$$$$$$$$$$ --> Message over sized so we are trimming it off! <-- $$$$$$$$$$$$$$$$$$"
        @description_html = "#{@description_html[0,MESSAGE_LIMIT]}<b>[message_cliped]</b>"
      end
    end

    def cleansed_html
     @cleaned_html_body ||= begin
       cleansed_html = run_with_timeout(HtmlSanitizerTimeoutError) { 
         begin
           result = nil
           format_html if params[:html].present?
           result = Helpdesk::HTMLSanitizer.clean params[:html]
         rescue SystemStackError => e
          result = handle_system_stack_error e
         end
         result
       }
     end 
   end

    def remove_survey_div parsed_html
      survey_div = parsed_html.css("div[title='freshdesk_satisfaction_survey']")
      survey_div.remove unless survey_div.blank?
    end

    def text_to_html(body)
      result_string = ""
      body.each_char.with_index do |char, i|
        case (char)
        when "&"
          result_string << "&amp;"
        when "<"
          result_string << "&lt;"
        when ">"
          result_string << "&gt;"
        when "\t"
          result_string << "&nbsp;&nbsp;&nbsp;&nbsp;"
        when "\n"
          result_string << "<br>"
        when "\""
          result_string << "&quot;"
        when "\'"
          result_string << "&#39;"
        else
          result_string << char
        end
      end
      "<p>" + result_string + "</p>"
    end

    def body_html_with_formatting(body,email_cmds_regex)
      body = body.gsub(email_cmds_regex,'<notextile>\0</notextile>')
      to_html = text_to_html(body)

      # Process auto_link if the content is less than 300 KB, otherwise leave as text.
      if body.size < MAXIMUM_CONTENT_LIMIT
        body_html = auto_link(to_html) { |text| truncate(text, :length => 100) }
      else
        body_html = sanitize(to_html)
      end

      html = white_list(body_html)
      html.gsub!("&amp;amp;", "&amp;")
      html
    end

  def add_ticket_tags(tags_to_be_added, ticket)
    tags_to_be_added.each do |tag|
      ticket.tags << tag
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e) 
  end

  def check_primary(ticket,account)
    parent_ticket_id = ticket.schema_less_ticket.parent_ticket
    if !parent_ticket_id
      return nil
    elsif account.features_included?(:archive_tickets) && parent_ticket_id
      parent_ticket = ticket.parent
      unless parent_ticket
        archive_ticket = Helpdesk::ArchiveTicket.find_by_ticket_id(parent_ticket_id)
        archive_child_ticket = archive_ticket.ticket if archive_ticket
        return archive_child_ticket if archive_child_ticket
        self.archived_ticket = archive_ticket
        return archived_ticket
      end
    else
      return ticket.parent
    end
  end

  def permissible_ccs(user, cc_emails, account)
    cc_emails, params[:dropped_cc_emails] = fetch_permissible_cc(user, cc_emails, account)
    cc_emails
  end   

  def verify
    Rails.logger.debug params[:verification_key]
    if params[:verification_key].present?
      stored_webhook_key = account_webhook_key_from_cache(Account::MAIL_PROVIDER[:sendgrid])
      if stored_webhook_key.nil? or stored_webhook_key.webhook_key.nil?
        Rails.logger.info "VERIFICATION KEY is there. But AccountWebhookKey Record is not present for the key #{params[:verification_key]}"
      else
        verification = (stored_webhook_key.webhook_key == params[:verification_key] ? true : false)
        Rails.logger.info "VERIFICATION KEY match for account #{Account.current.id} : #{verification}"
        # return verification
      end
    else
      Rails.logger.info "VERIFICATION KEY is not present for the account #{Account.current.id} with the envelope address #{params[:envelope]}"
    end
    # Returning true by default.
    return true
  end  

  def update_spam_data(ticket)
    if params[:spam_info].present?
      if !params[:spam_info]['rules'].nil? && (params[:spam_info]['rules'] & custom_bot_attack_rules).size != 0
        ticket.skip_notification = true
        ticket.spam = true
        Rails.logger.info 'Skip notification set and ticket marked as spam due to CUSTOM_BOT_ATTACK'
      end
      if !ticket.nil? && !ticket.account.nil? && antispam_enabled?(ticket.account)
        begin
          ticket.spam_score = params[:spam_info]['score']
          ticket.spam = true if params[:spam_info]['spam'] == true
          Rails.logger.info "Spam rules triggered for ticket with message_id #{params[:message_id]}: #{params[:spam_info]['rules']}"
        rescue StandardError => e
          Rails.logger.debug e.message
        end
      end
    end
    ticket.schema_less_ticket.additional_info.merge!(generate_spoof_data_hash(params[:spam_info])) if Account.current.email_spoof_check_feature?
    ticket
  end

  def processed_email_data(processed_status, account_id = -1, model = nil)
    data = { :account_id => account_id, :processed_status => processed_status }
    if processed_status == PROCESSED_EMAIL_STATUS[:success] && model.present?
      if model.class.name.include?("Ticket")
        data.merge!(:ticket_id => model.id, :type => PROCESSED_EMAIL_TYPE[:ticket], :note_id => "-1", :article_id => "-1", :display_id => model.display_id) # check with nil values
      elsif model.class.name.include?("Note")
        data.merge!(:ticket_id => model.notable_id, :note_id => model.id, :type => PROCESSED_EMAIL_TYPE[:note], :article_id => "-1")
        data.merge!(:display_id => model.notable.display_id) unless model.notable.nil?
      elsif model.class.name.include?("Article")
        data.merge!(:article_id => model.id, :type => PROCESSED_EMAIL_TYPE[:article], :ticket_id => "-1", :note_id => "-1")
      end
    end
    data.merge!(:message_id => message_id) if (account_id == -1)
    data.with_indifferent_access      
  end

  # to handle the div tag issue. Makes the text part as content. saves html part as attachment.
  def handle_system_stack_error e
    Rails.logger.info "Error during html sanitize : #{e.message}, #{e.backtrace}"
    account = Account.current
    email_cmds_regex = get_email_cmd_regex(account) 
    result = ((params[:text].nil? || params[:text].empty?) ? "" : body_html_with_formatting(params[:text],email_cmds_regex)) 
    result = "<br><p style=\"color:#FF2625;\"><b> *** Warning: This email might have some content missing. Please open the attached file original_email.html to see the entire message. *** </b></p><br>" + result
    original_email_content = StringIO.new(params[:html])
    original_email_content.class.class_eval { attr_accessor :original_filename, :content_type }
    original_email_content.content_type = "text/html"
    original_email_content.original_filename = "original_email.html"
    params[:attachments] = params[:attachments] + 1
    params["attachment#{params[:attachments]}"] = original_email_content
    result
  end

  # parse html to nokogiri
  # to faster execution => to reduce no of lines in html
  # remove deprecated styles if any(can be customizable specific to account)
  def format_html
      formatted = deprecated_css_parsing_enabled? ? deprecated_css_parsing : parse_html
      params[:html] = formatted.to_html if formatted.present?
  end

  def parse_html
    #HTML FORMAT was removed in the sanitize gem version("4.6.5").
    #So HTML content has huge line size which leads to high memory consumption and CPU utilization for the process.
    #So doing HTML FORMAT through Nokogiri before passing to sanitize.
    run_with_timeout(NokogiriTimeoutError) { Nokogiri::HTML(params[:html]) }
  end

  #deprecated css parsing

  def email_deprecated_style_parsing_key
    DEPRECATED_STYLE_PARSING % {:account_id => Account.current.id}
  end

  def deprecated_css_parsing_enabled?
    Account.current.launched?(:email_deprecated_style_parsing)
  end

  def deprecated_css_parsing
    dep_parse_html = parse_html
    styles_to_change = get_others_redis_key(email_deprecated_style_parsing_key)
    if styles_to_change.present? && dep_parse_html.present?
      styles_to_change = JSON.parse(styles_to_change)
      styles_to_change.each do |tag, property|
        dep_parse_html.css(tag).each do |node| 
          property.each do |oldproperty, newproperty|
            if node.attributes.keys.include?(oldproperty)
              old_attr_value = node.attributes[oldproperty].value
              node.attributes.map do |k, v| 
                v.name = newproperty if v.name == oldproperty
                v.value = v.value << newproperty.to_s + ": " + old_attr_value + ";" if v.name == "style" && old_attr_value.present?  # overrite inline  style
              end 
            end
          end
        end
      end
    end
    return dep_parse_html 
  end

  #deprecated css parsing//
 
  alias_method :parse_cc_email, :parse_cc_email_new
  alias_method :parse_to_emails, :parse_to_emails_new

end