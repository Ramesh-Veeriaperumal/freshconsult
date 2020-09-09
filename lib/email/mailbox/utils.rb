module Email::Mailbox::Utils
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Email::Mailbox::Constants
  include Email::Mailbox::Oauth2Helper
  
  def construct_to_email(to_email, account_full_domain)
     email_split  = to_email.split('@')
     email_name   = email_split[0] || ''
     email_domain = email_split[1] || ''

     account_full_domain = account_full_domain.downcase
     reply_email  = '@' + account_full_domain

     if(email_domain.downcase == account_full_domain)
        reply_email = email_name + reply_email
     else
        reply_email = email_domain.gsub(/\./,'') + email_name + reply_email
     end
     reply_email
  end
  
  def gmail_oauth_url(app_config)
    AppConfig['integrations_url'][Rails.env] + 
      Liquid::Template.parse(GMAIL_OAUTH_URL).render(app_config)
  end

  def outlook_oauth_url(app_config)
    AppConfig['integrations_url'][Rails.env] +
      Liquid::Template.parse(OUTLOOK_OAUTH_URL).render(app_config)
  end

  def populate_redis_oauth(members_hash, provider, expiry = true)
    oauth_redis_obj = Email::Mailbox::OauthRedis.new(provider: provider)
    oauth_redis_obj.populate_hash(members_hash, expiry)
    oauth_redis_obj.redis_key
  end

  def update_mailbox_error_type
    from_email = from.try(:[], 0)
    refresh_access_token(email_mailbox(from_email).smtp_mailbox) && return if oauth_delivery_method? && from_email.present?

    error_type = SMTP_AUTHENTICATION_ERROR_CODE
    if from_email.present?
      email_config = email_mailbox(from_email)
      email_config.smtp_mailbox.tap do |smtp_mailbox|
        if smtp_mailbox.error_type != error_type
          smtp_mailbox.error_type = error_type
          smtp_mailbox.save
          Rails.logger.info("custom mailbox status : updating the error_type for account : #{Account.current.id}, mailbox_id : #{smtp_mailbox.id}, value : #{error_type}")
        else
          Rails.logger.info("custom mailbox status : Same error type as before for account : #{Account.current.id}, mailbox_id : #{smtp_mailbox.id}, value : #{error_type}")
        end
      end
    end
  rescue StandardError => e
    Rails.logger.info "Exception in update_mailbox_error_type account: #{Account.current.id} - error #{e.message}"
  end

  def oauth_delivery_method?
    self.delivery_method.settings[:authentication] == OAUTH
  end

  def email_mailbox(from_email)
    Account.current.email_configs.find_by_reply_email(from_email)
  end
end
