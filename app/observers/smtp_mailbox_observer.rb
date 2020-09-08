class SmtpMailboxObserver < ActiveRecord::Observer

  include Mailbox::HelperMethods
  include Cache::Memcache::EmailConfig
  include Email::Mailbox::Constants
  include Email::Mailbox::GmailOauthHelper

  def before_create mailbox
    set_account(mailbox)
    encrypt_password(mailbox)
    encrypt_refresh_token(mailbox)
  end

  def before_update mailbox
    encrypt_password(mailbox)
    encrypt_refresh_token(mailbox)
    nullify_error_type_on_reauth(mailbox)
  end

  def after_commit(mailbox)
    if mailbox.safe_send(:transaction_include_action?, :create)
      set_valid_access_token_key(mailbox.account_id, mailbox.id)
    elsif mailbox.safe_send(:transaction_include_action?, :update)
      set_valid_access_token_key(mailbox.account_id, mailbox.id) if changed_credentials?(mailbox) && mailbox.authentication == OAUTH
      clear_cache(mailbox)
      update_custom_mailbox_status(mailbox.account_id)
    elsif mailbox.safe_send(:transaction_include_action?, :destroy)
      delete_valid_access_token_key(mailbox.account_id, mailbox.id)
      clear_cache(mailbox)
      update_custom_mailbox_status(mailbox.account_id)
    end
  end
end
