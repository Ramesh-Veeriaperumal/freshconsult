# frozen_string_literal: true

module Email::Mailbox::Oauth2Helper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Integrations::OauthHelper

  def refresh_access_token(mailbox)
    access_token_response = HashWithIndifferentAccess.new(
      get_oauth2_access_token(
        Email::Mailbox::Constants::APP_NAME_BY_SERVER_KEY[server_key(mailbox)],
        mailbox.refresh_token,
        Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox)]
      )
    )
    mailbox.access_token = access_token_response[:access_token].token
    mailbox.save!
  rescue OAuth2::Error => e
    Rails.logger.info "Error refreshing access token : #{e}"
    update_mailbox_error(mailbox, Email::Mailbox::Constants::AUTH_ERROR)
    delete_valid_access_token_key(mailbox)
  end

  def add_valid_access_token_key(mailbox)
    set_others_redis_with_expiry(
      format(
        OAUTH_ACCESS_TOKEN_VALIDITY,
        provider: Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox)],
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.id
      ),
      true,
      ex: Email::Mailbox::Constants::ACCESS_TOKEN_EXPIRY
    )
  end

  def access_token_expired?(mailbox)
    !redis_key_exists?(
      format(
        OAUTH_ACCESS_TOKEN_VALIDITY,
        provider: Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox)],
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.id
      )
    )
  end

  def update_mailbox_error(mailbox, error_type = nil)
    mailbox.error_type = error_type
    mailbox.save!
  end

  def failed_mailbox?(from_email)
    mailbox = Account.current.email_configs.find_by_reply_email(from_email).smtp_mailbox
    mailbox.error_type.present?
  end

  def delete_valid_access_token_key(mailbox)
    remove_others_redis_key(
      format(
        OAUTH_ACCESS_TOKEN_VALIDITY,
        provider: Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox)],
        account_id: mailbox.account_id,
        smtp_mailbox_id: mailbox.id
      )
    )
  end

  def server_key(mailbox)
    mailbox.server_name.include?(Email::Mailbox::Constants::GMAIL) ? Email::Mailbox::Constants::GMAIL : Email::Mailbox::Constants::OFFICE365
  end
end
