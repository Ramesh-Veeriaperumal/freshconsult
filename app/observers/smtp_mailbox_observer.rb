class SmtpMailboxObserver < ActiveRecord::Observer

  include Mailbox::HelperMethods
  include Cache::Memcache::EmailConfig
  include Email::Mailbox::Constants
  include Email::Mailbox::Oauth2Helper

  def before_create mailbox
    set_account(mailbox)
    encrypt_password(mailbox)
  end

  def before_update mailbox
    encrypt_password(mailbox)
    nullify_error_type_on_reauth(mailbox)
  end

  def after_commit mailbox
    if mailbox.safe_send(:transaction_include_action?, :create)
      add_valid_access_token_key(mailbox) if mailbox.authentication == OAUTH
    elsif mailbox.safe_send(:transaction_include_action?, :update)
      add_valid_access_token_key(mailbox) if changed_credentials?(mailbox) && mailbox.authentication == OAUTH
      clear_cache(mailbox)
    elsif mailbox.safe_send(:transaction_include_action?, :destroy)
      delete_valid_access_token_key(mailbox)
      clear_cache(mailbox)
    end
  end
end
