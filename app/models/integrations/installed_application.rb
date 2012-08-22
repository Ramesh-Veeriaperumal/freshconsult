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

  def method_missing(meth_name, *args, &block)
    matched = /configs_([^=]*)(=?)/.match(meth_name.to_s)
    if matched.blank?
      super
    else
      input_key = matched[1]
      self[:configs] = self[:configs] || {}
      input_values = self[:configs][:inputs]
      if matched[2] == "="
        input_values = input_values || {}
        input_values[input_key] = args[0]
      else
        input_values[input_key] unless input_values.blank?
      end
    end
  end

  private
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
