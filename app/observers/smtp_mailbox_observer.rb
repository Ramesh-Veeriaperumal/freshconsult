class SmtpMailboxObserver < ActiveRecord::Observer

  include Mailbox::HelperMethods
  include Email::Mailbox::Constants
  include Email::Mailbox::Oauth2Helper

  def before_create mailbox
    set_account(mailbox)
    encrypt_password(mailbox)
    add_reauth_error_to_force_oauth_migration(mailbox, OAUTH_MIGRATION_ERROR) if mailbox.authentication != OAUTH
  end

  def before_update mailbox
    encrypt_password(mailbox)
    nullify_error_type_on_reauth(mailbox)
    add_reauth_error_to_force_oauth_migration(mailbox, OAUTH_MIGRATION_ERROR) if (mailbox.error_type.nil? || mailbox.error_type.zero?) && mailbox.authentication != OAUTH
  end

  def after_commit(mailbox)
    if mailbox.safe_send(:transaction_include_action?, :create)
      add_valid_access_token_key(mailbox) if mailbox.authentication == OAUTH
      add_reauth_mailbox_status mailbox.account_id if !mailbox.error_type.nil? && mailbox.error_type == OAUTH_MIGRATION_ERROR
    elsif mailbox.safe_send(:transaction_include_action?, :update)
      add_valid_access_token_key(mailbox) if changed_credentials?(mailbox) && mailbox.authentication == OAUTH
      update_custom_mailbox_status(mailbox.account_id)
      update_reauth_mailbox_status(mailbox.account_id)
    elsif mailbox.safe_send(:transaction_include_action?, :destroy)
      delete_valid_access_token_key(mailbox)
      update_custom_mailbox_status(mailbox.account_id)
      update_reauth_mailbox_status(mailbox.account_id)
    end
  end
end
