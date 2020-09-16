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
    account.allow_wildcard_ticket_create_enabled?
  end

  def assign_language(user, account, ticket)
    if ticket.spam 
      user.language = account.language
      user.save
    else
      if params[:text]
        text = text_for_detection(params[:text])
        if user.present? and user.language.nil?
          Rails.logger.info "language_detection => tkt_source:user.email, acc_id:#{Account.current.id}, req_id:#{user.id}, text:#{text}"
          language_detection(user.id, Account.current.id, text)
        end
      end  
    end 
  end
end
