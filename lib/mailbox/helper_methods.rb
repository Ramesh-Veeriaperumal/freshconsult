module Mailbox::HelperMethods

  include Redis::OthersRedis
  include Redis::Keys::Others

  PUBLIC_KEY = OpenSSL::PKey::RSA.new(File.read('config/cert/public.pem'))

  def decrypt_password(mailbox_password)
    decrypt_field(mailbox_password)
  end

  private

    def set_account mailbox
      mailbox.account = mailbox.email_config.account
    end

    def encrypt_password(mailbox)
      if mailbox.changed.include?('password') && mailbox.password.present?
        mailbox.password = encrypt_field(mailbox.password)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.error("Error encrypting password for mailbox : #{mailbox.inspect} , #{e.message}")
    end

    def encrypt_field(field)
      Base64.encode64(PUBLIC_KEY.public_encrypt(field))
    end

    def decrypt_field(field)
      private_key_file = 'config/cert/private.pem'
      password = 'freshprivate'
      private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file), password)
      private_key.private_decrypt(Base64.decode64(field))
    end

    def nullify_error_type_on_reauth(mailbox)
      mailbox.error_type = nil if mailbox.error_type.present? && (mailbox.changed.include?('encrypted_access_token') || mailbox.changed.include?('password'))
    end

    def changed_credentials?(mailbox)
      mailbox.previous_changes.key?(:encrypted_access_token)
    end

    def clear_custom_mailbox_status_key(account_id)
      remove_others_redis_key(custom_mailbox_status_key(account_id))
    end

    def custom_mailbox_status_key(account_id)
      format(CUSTOM_MAILBOX_STATUS_CHECK, account_id: account_id)
    end

    def add_custom_mailbox_status_key(account_id)
      set_others_redis_key(custom_mailbox_status_key(account_id), 1)
    end

    def update_custom_mailbox_status(account_id)
      if redis_key_exists?(custom_mailbox_status_key(account_id))
        clear_custom_mailbox_status_key account_id if Account.current.imap_mailboxes.errors.blank? && Account.current.smtp_mailboxes.errors.blank?
      elsif Account.current.imap_mailboxes.errors.present? || Account.current.smtp_mailboxes.errors.present?
        add_custom_mailbox_status_key account_id
      end
    end
end
