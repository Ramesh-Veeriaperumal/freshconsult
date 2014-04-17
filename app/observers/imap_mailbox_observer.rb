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

  def after_commit_on_create mailbox
    $sqs_mailbox.send_message(mailbox.imap_params("create"))
  end

  def after_commit_on_update mailbox
    $sqs_mailbox.send_message(mailbox.imap_params("update"))
  end

  def after_commit_on_destroy mailbox
    params = { :mailbox_id => mailbox.id, :account_id => mailbox.account_id, :action => "delete" }
    $sqs_mailbox.send_message(params.to_json)
  end

  private

    def set_imap_timeout mailbox
      mailbox.timeout = 60 * MailboxConstants::TIMEOUT_OPTIONS[mailbox.selected_server_profile.to_sym]
    end
end