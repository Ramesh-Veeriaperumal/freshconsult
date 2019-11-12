module Email::Mailbox::Utils
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Email::Mailbox::Constants
  
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
  
  def populate_redis_gmail_oauth(members_hash, expiry = true)
    gmail_oauth_redis_obj = Email::Mailbox::GmailOauthRedis.new
    gmail_oauth_redis_obj.populate_hash(members_hash, expiry)
    gmail_oauth_redis_obj.redis_key
  end
end
