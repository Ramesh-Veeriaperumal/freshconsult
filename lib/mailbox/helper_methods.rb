module Mailbox::HelperMethods

  PUBLIC_KEY = OpenSSL::PKey::RSA.new(File.read('config/cert/public.pem'))

  def decrypt_password(mailbox_password)
    decrypt_field(mailbox_password)
  end

  def decrypt_refresh_token(mailbox_refresh_token)
    decrypt_field(mailbox_refresh_token)
  end

  private

    def set_account mailbox
      mailbox.account = mailbox.email_config.account
    end

    def encrypt_refresh_token(mailbox)
      if mailbox.changed.include?('refresh_token') && mailbox.refresh_token.present?
        mailbox.refresh_token = encrypt_field(mailbox.refresh_token)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.error("Error encrypting refresh token for mailbox : #{mailbox.inspect} , #{e.message}")
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
end
