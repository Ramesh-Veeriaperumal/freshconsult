module Email::PerformUtil
  include Helpdesk::Email::Constants

  def check_for_wildcard(email_config, account, to_email)
    return { status: false } if allow_wild_card(account)

    email_config = account.all_email_configs.find_by_to_email(to_email[:email]) if email_config.blank?

    return wild_card_found(account, to_email[:email]) if email_config.blank?

    { status: false }
  end

  def wild_card_found(account, envelop_to)
    email_processing_log("Email Processing Failed. Wildcard found #{account.id} ", envelop_to)
    wc_failure_result(account)
  end

  def wc_failure_result(account)
    { status: true, message: processed_email_data(PROCESSED_EMAIL_STATUS[:wildcard_email], account.id) }
  end

  def allow_wild_card(account)
    !account.launched?(:prevent_wc_ticket_create) || account.launched?(:allow_wildcard_ticket_create)
  end
end