require 'openssl'
require 'base64'

module Integrations::AppsUtil
  def get_installed_apps
    @installed_applications = Integrations::InstalledApplication.find(:all, :conditions => ["account_id = ?", current_account])
  end

  def get_encrypted_value(params)
    begin
      if params[:encryptiontype] == "md5"
      params[:password] = Digest::MD5.hexdigest(params[:password]) unless params[:password].blank?
    else
      public_key_file = 'config/cert/public.pem'
      public_key = OpenSSL::PKey::RSA.new(File.read(public_key_file))
      params[:password] = Base64.encode64(public_key.public_encrypt(params[:password])) unless params[:password].blank?
    end  
    rescue Exception => e
      Rails.logger.error("Error encrypting password for the installed application. #{e.message}")
    end
    return params
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

  def execute(clazz_str, method_str, args=[])
    unless clazz_str.blank?
      obj = clazz_str.constantize
      obj = obj.new unless obj.respond_to?(method_str)
      if obj.respond_to?(method_str)
        obj.send(method_str, args)
      else
        raise "#{clazz_str} is not responding to #{method_str}."
      end
    end
  end

  def replace_liquid_values(liquid_template, data)
    if liquid_template.class == Hash
      liquid_template.map {|key, value| liquid_template[key] = replace_liquid_values(value, data)}
    elsif liquid_template.class == Array
      liquid_template.each_index {|i| liquid_template[i] = replace_liquid_values(liquid_template[i], data)}
    elsif liquid_template.class == String
      data = data.attributes if data.respond_to? :attributes
      Liquid::Template.parse(liquid_template).render(data)
    end
  end
end
