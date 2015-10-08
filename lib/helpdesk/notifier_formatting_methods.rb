module Helpdesk::NotifierFormattingMethods

  include Redis::RedisKeys
  include Redis::OthersRedis
  include AccountConstants

  REPLY_PREFIX = "Re:"
  FWD_PREFIX  = "Fwd:"

  def default_reply_subject(ticket)
    "#{encoded_ticket_id(ticket)} #{ticket.subject}"
  end

  def formatted_subject(ticket)
    subject = reply_subject(true, ticket)
    "#{REPLY_PREFIX} #{subject}"
  end

  def fwd_formatted_subject(ticket)
    subject = reply_subject(false, ticket)
    "#{FWD_PREFIX} #{subject}"
  end

  def reply_subject(reply, ticket)
    template = ticket.account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_REPLY_TEMPLATE)
    subject_template = reply ? template.get_requester_template(ticket.requester).first : template.requester_subject_template
    subject = Liquid::Template.parse(subject_template).render('ticket' => ticket,
                'helpdesk_name' => ticket.account.portal_name ).html_safe
    subject.blank? ? default_reply_subject(ticket) : subject
  end

  def generate_body_html(html)
    html_part = Nokogiri::HTML(html)
    if html_part.at_css('img.inline-image')
      html_part.at_css("body").inner_html.html_safe
    else
      html.html_safe
    end
  end

  def encoded_ticket_id ticket
    ticket.encode_display_id unless ticket.account.features?(:id_less_tickets)
  end

  def generate_email_references(ticket)
    ticket.header_info_present? ? "<#{ticket.header_info[:message_ids].join(">,<")}>" : ""
  end

  def in_reply_to(ticket)
    ret_val = ""
    if ticket.header_info_present?
      message_id = ticket.header_info[:message_ids].first
      message_key = EMAIL_TICKET_ID % { :account_id => ticket.account_id, 
                                        :message_id => message_id }
      value = get_others_redis_key(message_key)
      ret_val = (value =~ /:(.+)/) ? "<#{$1}>" : "<#{message_id}>"
    end
    ret_val
  end

  def handle_inline_attachments(inline_attachments, html, account)
    html_part = Nokogiri::HTML(html)
    html_part.xpath('//img[@class="inline-image"]').each do |inline|
      inline_attachment = account.attachments.find_by_id(inline['data-id'])
      if inline_attachment
        inline.set_attribute('src', inline_attachments.inline[inline_attachment.content_file_name].url)
        inline.set_attribute('height', inline['data-height']) unless inline['data-height'].blank?
      end
    end
  end

  def validate_emails(addresses, model)
    return [] unless addresses
    addresses = addresses.join(",") if addresses.is_a? Array
    parsed_emails = Mail::AddressList.new(addresses).addresses
    return [] if parsed_emails.blank?
    msg = " #{model.class.name} : #{model.id} Account ID : #{model.account_id}"
    emails = []
    name = ""
     
    parsed_emails.each_with_index do |email, index|
      if email.address =~ EMAIL_REGEX
        if email.name.present?
          email.name.prepend(name) and name="" if name.present?
          emails << "#{format(email.name)} <#{email.address.downcase.strip}>".strip
        else
          emails << email.address.downcase.strip
        end
      else
        Rails.logger.debug "Rejecting #{email.address} from #{addresses}" + msg
        name << "#{email.address} , "
      end
    end
    emails.compact.uniq
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{addresses}" + msg + 
                        "#{e.message} : #{e.backtrace}"
    addresses
  end

  def format(name)
    (name =~ SPECIAL_CHARACTERS_REGEX and name !~ /".+"/) ? "\"#{name}\"" : name
  end
end
