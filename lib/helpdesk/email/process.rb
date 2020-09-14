# encoding: utf-8
class Helpdesk::Email::Process
  include EmailCommands
  include Helpdesk::Email::ParseEmailData
  include Helpdesk::Email::HandleArticle
  include Helpdesk::DetectDuplicateEmail
  include ActionView::Helpers
  include WhiteListHelper
  include Helpdesk::ProcessByMessageId
  include AccountConstants
  include EmailHelper

  #All email meta data and parsing of email values are done on parse_email_data.rb. Please refer while viewing this file.

  attr_accessor :to_email, :common_email_data, :params, :account, :user, :kbase_email, :start_time

  MAPPING_ENCODING = {
    "ks_c_5601-1987" => "CP949",
    "unicode-1-1-utf-7"=>"UTF-7",
    "_iso-2022-jp$esc" => "ISO-2022-JP",
    "charset=us-ascii" => "us-ascii",
    "iso-8859-8-i" => "iso-8859-8",
    "unicode" => "utf-8"
  }

  def initialize args
    self.params = args
    self.to_email = parse_to_email #In parse_email_data
  end

  def perform
    email_processing_log "Email received: Message-Id #{params["Message-Id"]}"
    self.start_time = Time.now.utc
    shardmapping = ShardMapping.fetch_by_domain(to_email[:domain])
    unless shardmapping.present?
      email_processing_log "Email Processing Failed: No Shard Mapping found!", to_email[:email]
      return
    end
    return shardmapping.status  unless shardmapping.ok?
    Sharding.select_shard_of(to_email[:domain]) do
      self.account = Account.find_by_full_domain(to_email[:domain])
      if account && account.allow_incoming_emails?
        accept_email
      else
        email_processing_log "Email Processing Failed: No active Account found!", to_email[:email]
      end
    end
  end

  def accept_email
    account.make_current
    TimeZone.set_time_zone
    self.common_email_data = email_metadata #In parse_email_data
    if mail_from_email_config?
      email_processing_log "Email Processing Failed: From-email and Reply-email are same!", to_email[:email]
      return
    end
      # encode_stuffs
    if account.features?(:domain_restricted_access)
      wl_domain  = account.account_additional_settings_from_cache.additional_settings[:whitelisted_domain]
      unless Array.wrap(wl_domain).include?(common_email_data[:from][:domain])
        email_processing_log "Email Processing Failed: Not a White listed Domain!", to_email[:email]
        return
      end
    end    
    if (common_email_data[:from][:email] =~ EMAIL_VALIDATOR).nil?
      error_msg = "Invalid email address found in requester details - #{common_email_data[:from][:email]} for account : #{account.id}"
      Rails.logger.debug error_msg
      return
    end
    check_tnef_message_id

    self.user = existing_user(common_email_data[:from])

    unless  user
      construct_html_param
      create_new_user(common_email_data[:from], common_email_data[:email_config], params["body-plain"])
    else
      if user.blocked?
        email_processing_log "Email Processing Failed: Blocked User!", to_email[:email]
        return
      end
      construct_html_param
    end

    if (user.nil? && !account.restricted_helpdesk?)
      email_processing_log "Email Processing Failed: Blank User!", to_email[:email]
      return
    end

    set_current_user(user)

    self.common_email_data[:cc] = permissible_ccs(user, self.common_email_data[:cc], account)

    get_necessary_details
    return if duplicate_email?(common_email_data[:from][:email],
                               common_email_data[:to][:email],
                               common_email_data[:subject],
                               params["Message-Id"][1..-2])
    assign_to_ticket_or_kbase
  end

  def check_tnef_message_id
    return if params["Message-Id"].present?
    begin
      msg_ar = JSON.parse(params["message-headers"]).select{|e| e[0] =~ /x-ms-tnef-correlator/i }.flatten
    rescue Exception => e
      msg_ar = []
    end
    if msg_ar.present? && msg_ar.length == 2 && msg_ar[1] =~ /<+([^>]+)/
      params["Message-Id"] = "<" << $1 << ">"
      Rails.logger.info "Fetched message-id from x-ms-tnef-correlator header: #{params["Message-Id"]}"
    end
  end

  def get_necessary_details
    self.common_email_data[:cc] = common_email_data[:cc].concat(additional_reply_to_emails || []).uniq if reply_to_feature
    self.common_email_data.merge!(additional_email_data) #In parse_email_data
    self.kbase_email = account.kbase_email
    self.to_email = support_email_from_recipients unless common_email_data[:email_config] #In parse_email_data
    self.common_email_data[:email_config] = account.email_configs.find_by_to_email(to_email[:email])
  end

  def mail_from_email_config?
    common_email_data[:email_config] && (common_email_data[:from][:email].to_s.downcase == common_email_data[:email_config].reply_email.to_s.downcase)
  end

  def assign_to_ticket_or_kbase
    handle_tickets unless kbase?
    create_article if kbase_email_available? && user.present?
  end

  def kbase_email_available?
    (kbase? || check_for_kbase_email)
  end

  def kbase?
    (to_email[:email] == kbase_email)
  end

	def handle_tickets 
    ticket_data = parse_ticket_metadata.merge(common_email_data) #In parse_email_data
    ticket = nil
    archive_ticket = nil
    ticket, archive_ticket = fetch_ticket_info(ticket_data, user, account) unless account.skip_ticket_threading_enabled?
    email_handler = Helpdesk::Email::HandleTicket.new(ticket_data, user, account, ticket)
    if ticket.present? || (archive_ticket.present? && archive_ticket.is_a?(Helpdesk::Ticket))
      self.user ||= get_user(common_email_data[:from], common_email_data[:email_config], params["body-plain"], true)
    end
    if user.blank?
      email_processing_log "Email Processing Failed: Blank User!", to_email[:email]
      return
    end
    ticket ? email_handler.create_note(start_time) : create_archive_link(archive_ticket, email_handler, start_time)
	end

  def create_archive_link(archive_ticket, email_handler, start_time)
    if account.features_included?(:archive_tickets)
      if archive_ticket && archive_ticket.is_a?(Helpdesk::ArchiveTicket)
        email_handler.archive_ticket = archive_ticket 
      elsif archive_ticket && archive_ticket.is_a?(Helpdesk::Ticket)
        email_handler.ticket = archive_ticket
        return email_handler.create_note(start_time)
      end
    end
    email_handler.create_ticket(start_time)
  end

  # def encode_stuffs
 #    charsets = params[:charsets].blank? ? {} : ActiveSupport::JSON.decode(params[:charsets])
 #    [ "body-html", "body-plain", "stripped-text", "stripped-html" ].each do |t_format|
 #      set_t_format(t_format) #if non_utf8_charset
 #      encode_characters(t_format, charsets) unless params[t_format].nil?
 #    end
	# end

 #  def encode_characters(t_format, charsets)
 #    self.charset_encoding = (charsets[t_format.to_s] || "UTF-8").strip()
 #    set_t_format(t_format) if non_utf8_charset
 #  end

 #  def set_t_format t_format
 #    begin
 #      params[t_format] = Iconv.new('utf-8//IGNORE', "UTF-8").iconv(params[t_format])
 #    rescue Exception => e
 #      handle_encoding_exception(e, t_format)
 #    end
 #  end

 #  def non_utf8_charset
 #    !charset_encoding.nil? and !(["utf-8","utf8"].include?(charset_encoding.downcase))
 #  end

 #  def handle_encoding_exception error, t_format
 #    if MAPPING_ENCODING["utf-8"]
 #      params[t_format] = Iconv.new('utf-8//IGNORE', MAPPING_ENCODING["utf-8"]).iconv(params[t_format])
 #    else
 #      log_encoding_error(error)
 #    end
 #  end

 #  def log_encoding_error e
 #    Rails.logger.error "Error While encoding in process email  \n#{e.message}\n#{e.backtrace.join("\n\t")} #{params}"
 #    NewRelic::Agent.notice_error(error,{:description => "Charset Encoding issue with ===============> utf-8 for #{params[t_format]}"})
 #  end

	def construct_html_param
    params["body-html"] = body_html_with_formatting(params["body-plain"],get_email_cmd_regex(account)) if html_blank?
    params["body-plain"] = params["body-plain"] || Helpdesk::HTMLSanitizer.plain(params["body-html"])
    params["stripped-html"] = body_html_with_formatting(params["stripped-text"],get_email_cmd_regex(account)) if stripped_html_blank?
    params["stripped-text"] = params["stripped-text"] || Helpdesk::HTMLSanitizer.plain(params["stripped-html"])
	end
  
  def html_blank?
    Helpdesk::HTMLSanitizer.plain(params["body-html"]).blank? && !params["body-plain"].blank?
  end

  def stripped_html_blank?
    Helpdesk::HTMLSanitizer.plain(params["stripped-html"]).blank? && !params["stripped-text"].blank?
  end 
  def set_current_user(user)
    user.make_current if user.present?
  end
end
