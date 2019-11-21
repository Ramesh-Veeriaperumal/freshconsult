module Email::Mailbox::GmailOauthHelper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Integrations::OauthHelper

  def refresh_access_token(mailbox)
    access_token_response = HashWithIndifferentAccess.new(
      get_oauth2_access_token(
        Email::Mailbox::Constants::GOOGLE_OAUTH2,
        mailbox.decrypt_refresh_token(mailbox.refresh_token),
        Email::Mailbox::Constants::GOOGLE_OAUTH2
      )
    )
    mailbox.password = access_token_response[:access_token].token
    mailbox.save!
  rescue OAuth2::Error => e
    Rails.logger.info "Error refreshing access token : #{e}"
    update_mailbox_error_type(mailbox, Email::Mailbox::Constants::AUTH_ERROR)
  end

  def set_valid_access_token_key(account_id, mailbox_id)
    set_others_redis_with_expiry(
      format(
        GMAIL_ACCESS_TOKEN_VALIDITY,
        account_id: account_id,
        smtp_mailbox_id: mailbox_id
      ),
      true,
      ex: Email::Mailbox::Constants::ACCESS_TOKEN_EXPIRY
    )
  end

  def access_token_expired?(account_id, mailbox_id)
    !redis_key_exists?(
      format(
        GMAIL_ACCESS_TOKEN_VALIDITY,
        account_id: account_id,
        smtp_mailbox_id: mailbox_id
      )
    )
  end

  def update_mailbox_error_type(mailbox, error_type = nil)
    mailbox.error_type = error_type
    mailbox.save!
  end

  def failed_mailbox?(from_email)
    mailbox = Account.current.email_configs.find_by_reply_email(from_email).smtp_mailbox
    mailbox.error_type.present?
  end

  def delete_valid_access_token_key(account_id, mailbox_id)
    remove_others_redis_key(
      format(
        GMAIL_ACCESS_TOKEN_VALIDITY,
        account_id: account_id,
        smtp_mailbox_id: mailbox_id
      )
    )
  end
end
