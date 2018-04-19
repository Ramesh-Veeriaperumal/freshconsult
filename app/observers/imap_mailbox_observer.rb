class ImapMailboxObserver < ActiveRecord::Observer

  include Mailbox::HelperMethods
  include Cache::Memcache::EmailConfig

  def before_create mailbox
    set_account mailbox
    set_imap_timeout mailbox
    encrypt_password mailbox
  end

  def before_update mailbox
    set_imap_timeout mailbox
    encrypt_password mailbox
  end
  
  def after_commit(mailbox)
    if mailbox.safe_send(:transaction_include_action?, :create)
      commit_on_create mailbox
    elsif mailbox.safe_send(:transaction_include_action?, :update)
      clear_cache mailbox
      check_error_and_send_mail(mailbox)
      # Send if error_type is not present. else, send if error_type is 0.
      commit_on_update(mailbox) if !mailbox.respond_to?(:error_type) || mailbox.error_type.to_i == 0
    elsif mailbox.safe_send(:transaction_include_action?, :destroy)
      clear_cache mailbox
      commit_on_destroy mailbox
    end
    true
  end
  
  private

  def commit_on_create mailbox
    $sqs_mailbox.send_message(mailbox.imap_params("create")) unless Rails.env.test?
  end

  def commit_on_update mailbox
    $sqs_mailbox.send_message(mailbox.imap_params("update")) unless Rails.env.test?
  end

  def commit_on_destroy mailbox
    params = { :mailbox_id => mailbox.id, :account_id => mailbox.account_id, :action => "delete" }
    $sqs_mailbox.send_message(params.to_json) unless Rails.env.test?
  end

  def check_error_and_send_mail mailbox
    return unless Account.current.imap_error_status_check_enabled? && mailbox.error_type.to_i > Admin::EmailConfig::Imap::SUSPENDED
    send_error_email(mailbox)
    rescue => e
      Rails.logger.error "Error in sending Custom Mailbox error notification, Error: #{e}, Mailbox: #{mailbox.inspect}"
  end

  def send_error_email mailbox
    subject = I18n.t("custom_mailbox_admin_email_notifications.subject")
    to_emails = Account.current.account_managers.map(&:email).join(",")

    options = {:to_emails => to_emails, :subject => subject, :email_mailbox => mailbox.user_name}
    CustomMailbox.error(options)
  end

    def set_imap_timeout mailbox
      mailbox.timeout = 60 * MailboxConstants::TIMEOUT_OPTIONS[mailbox.selected_server_profile.to_sym]
    end
end
