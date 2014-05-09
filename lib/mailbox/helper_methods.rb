module Mailbox::HelperMethods

  PUBLIC_KEY = OpenSSL::PKey::RSA.new(File.read('config/cert/public.pem'))

  private

    def set_account mailbox
      mailbox.account = mailbox.email_config.account
    end

    def encrypt_password mailbox
      if mailbox.changed.include?("password") and !mailbox.password.blank?
        mailbox.password = Base64.encode64(PUBLIC_KEY.public_encrypt(mailbox.password))
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.error("Error encrypting password for mailbox : #{mailbox.inspect} , #{e.message}")
    end
end