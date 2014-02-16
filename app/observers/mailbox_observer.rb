class MailboxObserver < ActiveRecord::Observer

  include Redis::RedisKeys

  PUBLIC_KEY = OpenSSL::PKey::RSA.new(File.read('config/cert/public.pem'))

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
    Resque.enqueue(Workers::Mailbox, {:account_id => mailbox.account.id, 
                :mailbox_id => mailbox.id, :action => "create"})
  end

  def after_commit_on_destroy mailbox
    Resque.enqueue(Workers::Mailbox, {:account_id => mailbox.account.id, 
                :mailbox_id => mailbox.id, :action => "delete"})
  end

  def after_commit_on_update mailbox
    Resque.enqueue(Workers::Mailbox, {:account_id => mailbox.account.id, 
                :mailbox_id => mailbox.id, :action => "update"})
  end

  private

  def set_account mailbox
    mailbox.account = mailbox.email_config.account
  end

  def set_imap_timeout mailbox
    mailbox.imap_timeout = 60 * Mailbox::TIMEOUT_OPTIONS[mailbox.selected_server_profile.to_sym]
  end

  def encrypt_password mailbox
    ["imap_password","smtp_password"].each do |field| 
      if mailbox.changed.include?(field) and !mailbox.send(field).blank?
        mailbox.send("#{field}=",Base64.encode64(PUBLIC_KEY.public_encrypt(mailbox.send(field))))
      end    
    end    
  rescue Exception => e
    NewRelic::Agent.notice_error(e)
    Rails.logger.error("Error encrypting #{field} for mailbox : #{mailbox.inspect} , #{e.message}")
  end
end