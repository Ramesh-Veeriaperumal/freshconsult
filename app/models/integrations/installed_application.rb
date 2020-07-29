class Integrations::InstalledApplication < ActiveRecord::Base
  include Integrations::AppsUtil
  include Integrations::Jira::WebhookInstaller
  include Cache::FragmentCache::Base
  include CentralLib::Util
  include ::Marketplace::GalleryConstants
  
  serialize :configs, Hash
  belongs_to :application, :class_name => 'Integrations::Application'
  belongs_to_account
  has_many :integrated_resources, :class_name => 'Integrations::IntegratedResource', :dependent => :destroy
  has_many :user_credentials, :class_name => 'Integrations::UserCredential', :dependent => :destroy
  has_many :external_notes,:class_name => 'Helpdesk::ExternalNote',:foreign_key => 'installed_application_id',:dependent => :delete_all
  has_many :app_business_rules, :class_name =>'Integrations::AppBusinessRule', :dependent => :destroy
  has_many :cti_calls, :class_name =>'Integrations::CtiCall', :dependent => :nullify
  has_many :cti_phones, :class_name =>'Integrations::CtiPhone', :dependent => :destroy
  has_many :va_rules, through: :app_business_rules
  has_many :sync_accounts, :class_name => 'Integrations::SyncAccount', :dependent => :destroy
  attr_protected :application_id, :account_id
  attr_accessible :configs, :application
  
  validate :check_existing_app, :on => :create
  before_destroy :before_destroy_customize
  after_destroy :delete_google_accounts, :after_destroy_customize
  before_save :before_save_customize
  before_create :before_create_customize, :unless => :skip_callbacks
  before_destroy :store_deleted_model
  after_create :after_create_customize, :verify_marketplace_billing
  after_save :after_save_customize
  after_save :store_model_changes
  before_update :store_old_configs

  after_commit :after_commit_on_create_customize, :on => :create
  after_commit :after_commit_on_update_customize, :on => :update
  after_commit :after_commit_on_destroy_customize, :on => :destroy, :unless => :skip_callbacks
  after_commit :after_commit_customize
  after_commit :clear_application_on_dip_from_cache
  after_commit :clear_fragment_caches, :if => :attachment_applications?
  after_commit :clear_application_hash_cache

  publishable on: [:create, :update, :destroy]

  include ::Integrations::AppMarketPlaceExtension

  attr_accessor :skip_callbacks, :skip_makrketplace_syncup

  scope :with_name, lambda { |app_name| where("applications.name = ?", app_name ).joins(:application).select('installed_applications.*')}
  delegate :oauth_url, :to => :application 
  scope :with_type_cti, -> { where("applications.application_type = 'cti_integration'").includes(:application) }

  concerned_with :presenter

  # serialized field doesn't have changes when key values are changed - @old_configs
  attr_accessor :old_configs

  def store_model_changes
    return @model_changes unless @model_changes.nil?
    @model_changes = self.changes
    @model_changes[:configs] = [@old_configs, self.configs]
  end

  def store_deleted_model
    @deleted_model_info = central_publish_payload
  end

  def store_old_configs
    @old_configs = Integrations::InstalledApplication.find(self.id).configs
  end
  
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

  def is_freshplug?
    self.application && self.application.freshplug?
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
        val = matched[1].blank? ? args[0] : self.safe_send(matched[1], args[0])
        self.configs[:inputs][input_key] = val
      else
        matched[1].blank? ? self.configs[:inputs][input_key] : self.safe_send(matched[1], self.configs[:inputs][input_key])
      end
    end
  end

  def user_access_token(current_user_id)
    user_cred = user_credentials.where(user_id: current_user_id).first
    return user_cred.auth_info['oauth_token'] if user_cred and user_cred.auth_info
  end

  def user_registered_email(current_user_id)
    user_cred = user_credentials.where(user_id: current_user_id).first
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
        if Integrations::Constants::SERVICE_APPS.include? self.application.name
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

    def check_existing_app
      ext_app = self.class.where(:account_id => Account.current.id, :application_id => self.application_id).any?
      if ext_app
        self.errors[:base] << t(:'flash.application.already') and return false
      end
    end

    def clear_application_on_dip_from_cache
      Account.current.clear_application_on_dip_from_cache
    end

    def attachment_applications?
      self.application and ["dropbox","box","onedrive"].include?(self.application.name)
    end

    def clear_application_hash_cache
      Account.current.clear_installed_application_hash_cache
    end

    def verify_marketplace_billing
      return unless should_verify_billing?

      Integrations::MarketplaceAppBillingWorker.perform_async(app_name: application.name)
    end

    def should_verify_billing?
      Account.current.marketplace_gallery_enabled? && NATIVE_PAID_APPS.include?(application.name)
    end
end
