class SmtpMailbox < ActiveRecord::Base
  self.primary_key = :id

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  def decrypt_password mailbox_password
    private_key_file = 'config/cert/private.pem'
    password = 'freshprivate'
    private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file),password)
    return private_key.private_decrypt(Base64.decode64(mailbox_password))
  end
end