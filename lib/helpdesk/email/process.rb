# encoding: utf-8
class Helpdesk::Email::Process
  include EmailCommands
  include Helpdesk::Email::ParseEmailData
  include Helpdesk::Email::HandleArticle
  include ActionView::Helpers
  include WhiteListHelper

  #All email meta data and parsing of email values are done on parse_email_data.rb. Please refer while viewing this file.

  attr_accessor :to_email, :common_email_data, :params, :account, :user, :kbase_email

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
    shardmapping = ShardMapping.fetch_by_domain(to_email[:domain])
    return unless shardmapping.present?
		Sharding.select_shard_of(to_email[:domain]) do 
			accept_email if get_active_account
		end
	end

  def get_active_account
    self.account = Account.find_by_full_domain(to_email[:domain])
    return (account and account.active?)
  end

  def accept_email
    account.make_current
    self.common_email_data = email_metadata #In parse_email_data
    return if mail_from_email_config?
    # encode_stuffs
    construct_html_param
    self.user = get_user(common_email_data[:from], common_email_data[:email_config], params["body-plain"]) #In parse_email_data
    return if (user.nil? or user.blocked?)
    get_necessary_details
    assign_to_ticket_or_kbase
  end

  def get_necessary_details
    self.common_email_data[:cc] = common_email_data[:cc].concat(additional_reply_to_emails || []).uniq if reply_to_feature
    self.common_email_data.merge!(additional_email_data) #In parse_email_data
    self.kbase_email = account.kbase_email
    self.to_email = support_email_from_recipients unless common_email_data[:email_config] #In parse_email_data
    self.common_email_data[:email_config] = account.email_configs.find_by_to_email(to_email[:email])
  end

  def mail_from_email_config?
    common_email_data[:email_config] && (common_email_data[:from][:email] == common_email_data[:email_config].reply_email)
  end

  def assign_to_ticket_or_kbase
    handle_tickets unless kbase?
    create_article if kbase_email_available?
  end

  def kbase_email_available?
    (kbase? || check_for_kbase_email)
  end

  def kbase?
    (to_email[:email] == kbase_email)
  end

	def handle_tickets 
		ticket_data = parse_ticket_metadata.merge(common_email_data) #In parse_email_data
		ticket_identifier = Helpdesk::Email::IdentifyTicket.new(ticket_data, user, account, self.common_email_data[:email_config])
    ticket = ticket_identifier.belongs_to_ticket
    email_handler = Helpdesk::Email::HandleTicket.new(ticket_data, user, account, ticket)
		ticket ? email_handler.create_note : email_handler.create_ticket
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

end