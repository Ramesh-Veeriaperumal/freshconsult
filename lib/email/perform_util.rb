module Email::PerformUtil
  include Helpdesk::Email::Constants

  def fwd_wildcards_result(params, email_config, account, to_email)
    email_config = account.all_email_configs.find_by_to_email(to_email[:email]) if email_config.blank?
    fwd_wildcard_result = validate_fwd_and_wildcards(params, email_config, account)
    if fwd_wildcard_result.present? && (fwd_wildcard_result[:processed_status] == PROCESSED_EMAIL_STATUS[:wildcard_email] || fwd_wildcard_result[:processed_status] == PROCESSED_EMAIL_STATUS[:fd_fwd_email])
      { status: true, message: fwd_wildcard_result }
    else
      { status: false }
    end
  rescue StandardError => e
    email_processing_log('Error in email processing perform util', e.message)
    { status: false }
  end

  def validate_fwd_and_wildcards(params, email_config, account)
    to_emails_arr = parse_to_emails
    cc_emails_arr = parse_cc_email
    email_to = extract_emails(to_emails_arr)
    email_cc = extract_emails(cc_emails_arr)
    valid_emails = email_to + email_cc
    email_config.present? ? check_with_email_config(account, email_config, valid_emails) : check_without_email_config(account, valid_emails)
  end

  def check_with_email_config(account, email_config, valid_emails)
    config_reply_email = parse_email(email_config.reply_email)
    config_to_email = parse_email(email_config.to_email)
    if check_wildcard_and_log(account, valid_emails, config_reply_email, config_to_email) && !account.launched?(:enable_wildcard_ticket_create)
      email_processing_log('Email Processing Failed. Email does not match the config emails ', valid_emails.inspect)
      return processed_email_data(PROCESSED_EMAIL_STATUS[:wildcard_email], account.id)
    end
    if account.launched?(:prevent_fwd_email_ticket_create) && !email_compare(valid_emails, config_reply_email[:email])
      email_processing_log('Email Processing Failed: Email sent to FD fwd addr ', valid_emails.inspect)
      return processed_email_data(PROCESSED_EMAIL_STATUS[:fd_fwd_email], account.id)
    end
  end

  def check_without_email_config(account, valid_emails)
    email_processing_log('Email Processing: wildcard found without config ', account.id)
    unless account.launched?(:enable_wildcard_ticket_create)
      email_processing_log('Email Processing Failed. Email does not match the config emails ', valid_emails.inspect)
      processed_email_data(PROCESSED_EMAIL_STATUS[:wildcard_email], account.id)
    end
  end

  def check_wildcard_and_log(account, valid_emails, config_reply_email, config_to_email)
    if !email_compare(valid_emails, config_reply_email[:email]) && !email_compare(valid_emails, config_to_email[:email])
      email_processing_log('Email Processing: wildcard found ', account.id)
      true
    end
  end

  def email_compare(email_arr, email)
    email_arr.include?(email.downcase) if email.present?
  end

  def extract_emails(email_arr)
    email_arr.map! { |e| sanitize_email(e) } if email_arr.present?
    email_arr.select!(&:present?) if email_arr.present?
    email_arr.presence || []
  end

  def sanitize_email(email)
    email_hash = parse_email(email)
    email_hash[:email].present? ? email_hash[:email].downcase.strip : nil
  end
end