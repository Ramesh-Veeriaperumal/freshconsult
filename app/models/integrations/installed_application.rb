class Integrations::InstalledApplication < ActiveRecord::Base
  include Integrations::AppsUtil
  include Integrations::Jira::WebhookInstaller
  
  serialize :configs, Hash
  belongs_to :application, :class_name => 'Integrations::Application'
  belongs_to_account
  has_many :integrated_resources, :class_name => 'Integrations::IntegratedResource', :dependent => :destroy
  has_many :user_credentials, :class_name => 'Integrations::UserCredential', :dependent => :destroy
  has_many :external_notes,:class_name => 'Helpdesk::ExternalNote',:foreign_key => 'installed_application_id',:dependent => :delete_all
  has_many :app_business_rules, :class_name =>'Integrations::AppBusinessRule', :dependent => :destroy
  has_many :va_rules, through: :app_business_rules
  attr_protected :application_id

  before_destroy :before_destroy_customize
  after_destroy :delete_google_accounts, :after_destroy_customize
  before_save :before_save_customize
  before_create :before_create_customize
  after_create :after_create_customize
  after_save :after_save_customize
  after_commit :after_commit_on_create_customize, :on => :create
  after_commit :after_commit_on_update_customize, :on => :update
  after_commit :after_commit_on_destroy_customize, :on => :destroy
  after_commit :after_commit_customize

  scope :with_name, lambda { |app_name| where("applications.name = ?", app_name ).joins(:application).select('installed_applications.*')}
  delegate :oauth_url, :to => :application 
  scope :with_type_cti, -> { where("applications.application_type = 'cti_integration'").includes(:application) }
  
  def to_liquid
    configs[:inputs]
  end

  def set_configs(inputs_hash)
    unless inputs_hash.blank?
      inputs_hash = sanitize_hash_values(inputs_hash)
      self.configs = {} if self.configs.blank?
      self.configs[:inputs] = inputs_hash || {} if self.configs[:inputs].blank?
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

  def user_access_token(current_user_id)
    user_cred = user_credentials.find(:first, :conditions => {:user_id => current_user_id})
    return user_cred.auth_info['oauth_token'] if user_cred and user_cred.auth_info
  end

  def user_registered_email(current_user_id)
    user_cred = user_credentials.find(:first, :conditions => {:user_id => current_user_id})
    return user_cred.auth_info['email'] if user_cred and user_cred.auth_info
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
	    end
  	end

    def before_save_customize
      execute_custom_clazz(:before_save)
    end

    def after_save_customize
      execute_custom_clazz(:after_save)
    end

    def before_create_customize
      execute_custom_clazz(:before_create)
    end

    def after_create_customize
      execute_custom_clazz(:after_create)
    end

    def before_destroy_customize
      execute_custom_clazz(:before_destroy)
    end

    def after_destroy_customize
      execute_custom_clazz(:after_destroy)
    end

    def after_commit_on_create_customize
      execute_custom_clazz(:after_commit_on_create)
    end

    def after_commit_on_update_customize
      execute_custom_clazz(:after_commit_on_update)
    end

    def after_commit_on_destroy_customize
      execute_custom_clazz(:after_commit_on_destroy)
    end

    def after_commit_customize
      execute_custom_clazz(:after_commit)
    end

    def execute_custom_clazz(action)
      return if self.application.blank?
      as = self.application.options[action]
      unless as.blank?
        if ["github"].include? self.application.name
          execute_service(as.delete(:clazz), as.delete(:method), self, as)
        else
          execute(as[:clazz], as[:method], self)
        end
      end
    end

    def sanitize_hash_values(inputs_hash)
      inputs_hash.each do |key, value|
        inputs_hash[key] = sanitize_value(value) unless key == "password"
      end
    end

    def sanitize_array_values(inputs_array)
      inputs_array.each_with_index do |value, index|
        inputs_array[index] = sanitize_value(value)
      end
    end

    def sanitize_value(value)
      value.is_a?(Array) ? sanitize_array_values(value) : ( value.is_a?(Hash) ?
          sanitize_hash_values(value) : RailsFullSanitizer.sanitize(value) )
    end
end
