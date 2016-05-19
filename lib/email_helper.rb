module EmailHelper
	include ActionView::Helpers::NumberHelper

  class NokogiriTimeoutError < Exception
  end

  class HtmlSanitizerTimeoutError < Exception
  end

  MAX_TIMEOUT = 7 # Sendgrid's timeout is 25 seconds
  REQUEST_TIMEOUT = 25
  SENDGRID_RETRY_TIME = 4.hours

  def verify_inline_attachments(item, content_id)
    content = "\"cid:#{content_id}\""
    if item.is_a? Helpdesk::Ticket
      item.description_html.include?(content)
    elsif item.is_a? Helpdesk::Note
      item.body_html.include?(content) || item.full_text_html.include?(content)
    end
  end

  def check_for_auto_responders(model, headers)
    model.skip_notification = true if auto_responder?(headers)
  end

  def check_support_emails_from(model, user, account)
    model.skip_notification = true if user && account.support_emails.any? {|email| email.casecmp(user.email) == 0}
  end

  def auto_responder?(headers)
    headers.present? && check_headers_for_responders(Hash[JSON.parse(headers)])
  end

  def check_headers_for_responders header_hash
    (header_hash["Auto-Submitted"] =~ /auto-(.)+/i || header_hash["Precedence"] =~ /(bulk|junk|auto_reply)/i).present?
  end
	
	def attachment_exceeded_message size
		I18n.t('attachment_limit_failed_message', :size => number_to_human_size(size)).html_safe
	end

  def invalid_ccs_message ccs
    I18n.t('cc_dropped_message', :emails => h(ccs.join(", ")))
  end

  def large_email(time=nil)
    @large_email ||= (Time.now.utc - (time || start_time)).to_i > REQUEST_TIMEOUT
  end

  def mark_email(key, from, to, subject, message_id)
    value = { "from" => from, "to" => to, "subject" => subject, "message_id" => message_id }
    set_others_redis_hash(key, value)
    set_others_redis_expiry(key, SENDGRID_RETRY_TIME)
  end

  def run_with_timeout error
    Timeout.timeout(MAX_TIMEOUT, error) do
      yield
    end
  rescue error => e
    subject = "ProcessEmail :: Timeout Error - #{error}"
    Rails.logger.debug "#{error} #{e.backtrace}"
    NewRelic::Agent.notice_error(e)
    DevNotification.publish(SNS["mailbox_notification_topic"], subject, e.backtrace.inspect)
    yield # Running the same code without timeout, as a temporary way. Need to handle it better
  end

  def cleanup_attachments model
    model.attachments.destroy_all if model.new_record?
  end

  def tokenize_emojis(msg_text)
    (msg_text.present? and Account.current.features?(:tokenize_emoji)) ? msg_text.tokenize_emoji : msg_text
  end

  def reply_to_private_note?(all_keys)
    all_keys.present? and all_keys.any? { |key| key.to_s.include? "private-notification.freshdesk.com" }
  end

  def reply_to_forward(all_keys)
    all_keys.present? && all_keys.any? { |key| key.to_s.include?("forward.freshdesk.com") }
  end
end
