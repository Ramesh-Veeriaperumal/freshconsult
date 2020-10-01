class ImapMailboxObserver < ActiveRecord::Observer

  include Mailbox::HelperMethods
  include EmailHelper
  include Email::Mailbox::Constants

  def before_create mailbox
    set_account mailbox
    set_imap_timeout mailbox
    encrypt_password mailbox
    add_reauth_error_to_force_oauth_migration(mailbox, OAUTH_MIGRATION_ERROR) if mailbox.authentication != OAUTH
  end

  def before_update mailbox
    set_imap_timeout mailbox
    encrypt_password mailbox
    clear_error_field(mailbox)
    add_reauth_error_to_force_oauth_migration(mailbox, OAUTH_MIGRATION_ERROR) if (mailbox.error_type.nil? || mailbox.error_type.zero?) && mailbox.authentication != OAUTH
  end
  
  def after_commit(mailbox)
    if mailbox.safe_send(:transaction_include_action?, :create)
      commit_on_create mailbox
      add_reauth_mailbox_status mailbox.account_id if !mailbox.error_type.nil? && mailbox.error_type == OAUTH_MIGRATION_ERROR
    elsif mailbox.safe_send(:transaction_include_action?, :update)
      update_custom_mailbox_status(mailbox.account_id)
      update_reauth_mailbox_status(mailbox.account_id)
      check_error_and_send_mail(mailbox)
      # Send if error_type is not present. else, send if error_type is 0.
      commit_on_update(mailbox) if !mailbox.respond_to?(:error_type) || mailbox.error_type.to_i.zero? || mailbox.error_type == OAUTH_MIGRATION_ERROR
    elsif mailbox.safe_send(:transaction_include_action?, :destroy)
      update_custom_mailbox_status(mailbox.account_id)
      update_reauth_mailbox_status(mailbox.account_id)
      commit_on_destroy mailbox
    end
    true
  end
  
  private

  def commit_on_create mailbox
    unless Rails.env.test?
      sqs_resp = AwsWrapper::SqsV2.send_message(SQS[:custom_mailbox_realtime_queue], mailbox.imap_params("create")) 
      Rails.logger.info "Mailbox Observer: commit_on_create: Sqs send message response: #{sqs_resp.inspect}"
    end
  end

  def commit_on_update mailbox
    unless Rails.env.test?
      sqs_resp = AwsWrapper::SqsV2.send_message(SQS[:custom_mailbox_realtime_queue], mailbox.imap_params("update")) 
      Rails.logger.info "Mailbox Observer: commit_on_update: Sqs send message response: #{sqs_resp.inspect}"
    end
  end

  def commit_on_destroy mailbox
    unless Rails.env.test?
      params = {:mailbox_attributes => {:id => mailbox.id, :account_id => mailbox.account_id, :application_id => imap_application_id}, :action => "delete"}
      sqs_resp = AwsWrapper::SqsV2.send_message(SQS[:custom_mailbox_realtime_queue], params.to_json) 
      Rails.logger.info "Mailbox Observer: commit_on_destroy: Sqs send message response: #{sqs_resp.inspect}"
    end
  end

  def check_error_and_send_mail mailbox
    return unless mailbox.error_type.to_i > Admin::EmailConfig::Imap::SUSPENDED
    
    send_error_email(mailbox)
    rescue => e
      Rails.logger.error "Error in sending Custom Mailbox error notification, Error: #{e}, Mailbox: #{mailbox.inspect}"
  end

  def send_error_email mailbox
    to_emails = Account.current.account_managers.map(&:email)

    options = { email_mailbox: mailbox.user_name }
    CustomMailbox.send_email_to_group(:error, to_emails, options)
  end

    def set_imap_timeout mailbox
      mailbox.timeout = 60 * MailboxConstants::TIMEOUT_OPTIONS[mailbox.selected_server_profile.to_sym]
    end

    def clear_error_field(mailbox)
      mailbox.error_type = 0 if can_clear_error_field?(mailbox)
    end

    def can_clear_error_field?(mailbox)
      (mailbox.password.present? && mailbox.changed.include?('password')) || (mailbox.encrypted_access_token.present? && mailbox.changed.include?('encrypted_access_token'))
    end
end
