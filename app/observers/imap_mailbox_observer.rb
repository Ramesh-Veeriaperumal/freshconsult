class ImapMailboxObserver < ActiveRecord::Observer

  include Mailbox::HelperMethods

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
    if mailbox.send(:transaction_include_action?, :create)
      commit_on_create mailbox
    elsif mailbox.send(:transaction_include_action?, :update) 
      commit_on_update mailbox
    elsif mailbox.send(:transaction_include_action?, :destroy)
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

    def set_imap_timeout mailbox
      mailbox.timeout = 60 * MailboxConstants::TIMEOUT_OPTIONS[mailbox.selected_server_profile.to_sym]
    end
end