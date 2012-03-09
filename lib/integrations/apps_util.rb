require 'openssl'
require 'base64'

module Integrations::AppsUtil
  def get_installed_apps
    @installed_applications = Integrations::InstalledApplication.find(:all, :conditions => ["account_id = ?", current_account])
  end

  def get_encrypted_value(text)
  	public_key_file = 'config/cert/public.pem'
  	public_key = OpenSSL::PKey::RSA.new(File.read(public_key_file))
  	encrypted_value = Base64.encode64(public_key.public_encrypt(text))
  end

  def self.get_decrypted_value(encrypted_value)
  	private_key_file = 'config/cert/private.pem'
  	password = 'freshprivate'
  	private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file),password)
  	decrypted_value = private_key.private_decrypt(Base64.decode64(encrypted_value))
  end

  def get_password_for_app(app_name, account)
      installed_app = Integrations::InstalledApplication.find(:first, :joins=>:application, 
                  :conditions => {:applications => {:name => app_name}, :account_id => account})
      encrypted_pwd = installed_app.configs[:inputs]['password']
      Integrations::AppsUtil.get_decrypted_value(encrypted_pwd)
  end
end
