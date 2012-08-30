class Integrations::InstalledApplication < ActiveRecord::Base
  include Integrations::AppsUtil

  serialize :configs, Hash
  belongs_to :application, :class_name => 'Integrations::Application'
  belongs_to :account
  has_many :integrated_resources, :class_name => 'Integrations::IntegratedResource', :dependent => :destroy
  attr_protected :application_id, :account_id

  before_destroy :before_destroy_customize
  after_destroy :delete_google_accounts, :after_destroy_customize
  before_save :before_save_customize
  after_save :after_save_customize

  named_scope :with_name, lambda { |app_name| {:joins=>"INNER JOIN applications ON applications.id=installed_applications.application_id", :conditions=>["applications.name = ?", app_name]}}

  def to_liquid
    configs[:inputs]
  end

  def set_configs(inputs_hash)
    unless inputs_hash.blank?
      self.configs = {} if self.configs.blank?
      self.configs[:inputs] = {} if self.configs[:inputs].blank?
      password = inputs_hash.delete("password")
      inputs_hash["password"] = encrypt(password) unless password.blank?
      ghostvalue = inputs_hash.delete("ghostvalue")
      inputs_hash["domain"] = inputs_hash["domain"] + ghostvalue unless ghostvalue.blank? or inputs_hash["domain"].blank?
      self.configs[:inputs] = self.configs[:inputs].merge(inputs_hash)
    end
  end

  def method_missing(meth_name, *args, &block)
    matched = /configs([^_]*)_([^=]*)(=?)/.match(meth_name.to_s)
    if matched.blank?
      super
    else
      input_key = matched[2]
      self.configs = {} if self.configs.blank?
      self.configs[:inputs] = {} if self.configs[:inputs].blank?
      if matched[3] == "="
        val = matched[1].blank? ? args[0] : self.send(matched[1], args[0])
        self.configs[:inputs][input_key] = val
      else
        matched[1].blank? ? self.configs[:inputs][input_key] : self.send(matched[1], self.configs[:inputs][input_key])
      end
    end
  end

  private
    def encrypt(data)
      begin
        unless data.nil?
          if self.configs_encryptiontype == "md5"
            return Digest::MD5.hexdigest(data)
          else
            public_key = OpenSSL::PKey::RSA.new(File.read("config/cert/public.pem"))
            Base64.encode64(public_key.public_encrypt(data))
          end
        end
      rescue Exception => e
        Rails.logger.error("Error encrypting password for the installed application. #{e.message}")
      end
    end

    def decrypt(data)
      unless data.nil?
        private_key = OpenSSL::PKey::RSA.new(File.read("config/cert/private.pem"), "freshprivate")
        decrypted_value = private_key.private_decrypt(Base64.decode64(data))
      end
    end

  	def delete_google_accounts
      return if self.application.blank?
	    if self.application.name == "google_contacts"
	      Rails.logger.info "Deleting all the google accounts corresponding to this account."
        Integrations::GoogleAccount.destroy_all ["account_id = ?", self.account]
        Integrations::GoogleAccount.destroy_all ["account = ?", self.account]
	    end
  	end

    def before_save_customize
      execute_custom_clazz(:before_save)
    end

    def after_save_customize
      execute_custom_clazz(:after_save)
    end

    def before_destroy_customize
      execute_custom_clazz(:before_destroy)
    end

    def after_destroy_customize
      execute_custom_clazz(:after_destroy)
    end

    def execute_custom_clazz(action)
      return if self.application.blank?
      as = self.application.options[action]
      unless as.blank?
        execute(as[:clazz], as[:method], self)
      end
    end
end
